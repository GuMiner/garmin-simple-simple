using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application;
using SimpleSimple.GoalTracker;
using SimpleSimple.Sensors;
using SimpleSimple.StepMeter;

// Renders the watch
class SimpleSimpleView extends WatchUi.WatchFace {
	var specialFont;
	var specialFontHeight;
	var specialCharacterFont;
	
	// Used to render the seconds properly
	var bottomMildFontCutoff;
    const FONT_CLIP_WIGGLE = 4;
    
    function initialize() {
        WatchFace.initialize();
        specialFont = WatchUi.loadResource(Rez.Fonts.TimeFont);
        specialCharacterFont = WatchUi.loadResource(Rez.Fonts.SpecialCharFont);
        specialFontHeight = Graphics.getFontHeight(specialFont);
        
        bottomMildFontCutoff = Graphics.getFontDescent(Graphics.FONT_NUMBER_MILD);
    }   
    
    const SCREEN_SIZE = 240;
	const DAY_MONTH_Y = 50;
	const SEC_Y = SCREEN_SIZE / 2 + 35;
	const CALORIES_Y = 21;
	
    // Fully updates the watch
    function onUpdate(dc) {
		// Reset the background
        dc.clearClip();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());

		// Render time info    	
        var clockTime = System.getClockTime();
        renderHrMin(dc, clockTime.hour, clockTime.min);
        renderDayMonth(dc);

        // Render all the various sensors
		renderBatteryPercent(dc);
		StepMeter.renderStepMeter(dc, SCREEN_SIZE);

		// Render per-second updates (seconds)
		onPartialUpdate(dc);
		
		// Must be last, because it may be affected by the seconds / calories location
		dc.clearClip();
		renderConnectionInformation(dc);
    }
    
    const DAY_MONTH_SPACE = 5;
	function renderDayMonth(dc) {
	   	var now = Time.now();
	       var mediumTimeFormat = Time.Gregorian.info(now, Time.FORMAT_MEDIUM);
	    	
	   	var dayStr = mediumTimeFormat.day_of_week;
	   	var dayNumberStr = Time.Gregorian.info(now, 0).day.format("%d");
	   	var monthStr = mediumTimeFormat.month;
			
		var fontSize = Graphics.FONT_SYSTEM_TINY;
		var dayStrLen =	dc.getTextWidthInPixels(dayStr, fontSize);
		var dayNumberStrLen = dc.getTextWidthInPixels(dayNumberStr, fontSize);
		var monthStrLen = dc.getTextWidthInPixels(monthStr, fontSize);
			
		// Center the font in the view
		var xStart = (SCREEN_SIZE - (dayStrLen + dayNumberStrLen + monthStrLen + 2 * DAY_MONTH_SPACE)) / 2;
		
		dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
		dc.drawText(xStart, DAY_MONTH_Y, fontSize, dayStr, Graphics.TEXT_JUSTIFY_LEFT);
		dc.drawText(xStart + dayStrLen + DAY_MONTH_SPACE, DAY_MONTH_Y, fontSize, dayNumberStr, Graphics.TEXT_JUSTIFY_LEFT);
		dc.drawText(xStart + dayStrLen + dayNumberStrLen + DAY_MONTH_SPACE * 2, DAY_MONTH_Y, fontSize, monthStr, Graphics.TEXT_JUSTIFY_LEFT);
	}
	
    function renderBatteryPercent(dc) {
    	var percentage = Sensors.getBatteryPercentage().toNumber();
	
		var x_c = SCREEN_SIZE / 2;
		var y_c = SCREEN_SIZE / 2;

		var spacerAngle = 4.4 * Math.PI / 180.0; // 180 / 40, 20 steps per quarter circle
		var spacerEnd = 2 * Math.PI / 180.0;
		var spacerHalf = spacerEnd / 2;

		var a_c = Math.PI / 2 + spacerEnd; // Rotation to start at the bottom and increment left
			
		var rad_out = SCREEN_SIZE / 2;
		var rad_in = rad_out - 10; // Arbitrary pixel amount
	
		var counter = 0;
		dc.setColor(0x00FF00, Graphics.COLOR_BLACK);
		for (var i = 0; i <= 40; i++)
		{
			// Change colors to indicate power levels
			if (i > percentage / 5) {
				dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
			}
		
			// Add tick marks appropriately.
			var rad_in_eff = rad_in;
			if (i % 5 == 0)
			{
				rad_in_eff -= 2;
			}
				
			if (i % 10 == 0)
			{
				rad_in_eff -= 3;
			}
		
			var cosSpacerAngle = Math.cos(a_c + i * spacerAngle);
			var sinSpacerAngle = Math.sin(a_c + i * spacerAngle);
			
			var x_o = x_c + rad_out * cosSpacerAngle;
			var y_o = y_c + rad_out * sinSpacerAngle;
	
			var x_1 = x_c + rad_out * Math.cos(a_c + i * spacerAngle - spacerEnd);
			var y_1 = y_c + rad_out * Math.sin(a_c + i * spacerAngle - spacerEnd);
	
			var x_2 = x_c + rad_in_eff * Math.cos(a_c + i * spacerAngle - spacerEnd);
			var y_2 = y_c + rad_in_eff * Math.sin(a_c + i * spacerAngle - spacerEnd);
	
			var x_3 = x_c + rad_in_eff * cosSpacerAngle;
			var y_3 = y_c + rad_in_eff * sinSpacerAngle;
			
			dc.fillPolygon([[x_o, y_o], [x_1, y_1], [x_2, y_2], [x_3, y_3]]);			
		}
    }

    function renderHrMin(dc, hours, minutes) {
        // Account for 12 / 24 hour time and midnight inconsistencies
        if (!System.getDeviceSettings().is24Hour) {
            if (hours > 12) {
                hours = hours - 12;
            }
        }
        
        if (hours == 0) {
        	hours = 12;
    	}
    	
        var timeString = Lang.format("$1$:$2$", [hours, minutes.format("%02d")]);

		var x = SCREEN_SIZE / 2;
		var y = (SCREEN_SIZE - specialFontHeight) / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(x, y, specialFont, timeString, Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    // Saved so the notification information is offset by the caolories width, if displayed on the top
    var caloriesWidth = 0;
    function renderCalories(dc) {
    	var cal = GoalTracker.getCalories();
    	if (null == cal) {
    		return;
    	}
    	
    	var str = cal.format("%d");    
	    dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
    	dc.drawText(SCREEN_SIZE / 2, CALORIES_Y, Graphics.FONT_XTINY, str, Graphics.TEXT_JUSTIFY_CENTER);
    	
    	var dim = dc.getTextDimensions(str, Graphics.FONT_XTINY);
    	caloriesWidth = dim[0];
    }

	// Saved so the notification information is offset by the seconds width, if displayed on the bottom
	var secondsWidth = 0;

	// Update the seconds on a partial update
	function onPartialUpdate(dc) {
		var renderSeconds = Application.getApp().getProperty("displaySeconds");
		if (renderSeconds != null && renderSeconds != 0) {
			return;
		}
		
		var secString = System.getClockTime().sec.format("%d");
		var fontSize = Graphics.FONT_NUMBER_MILD;
		var dim = dc.getTextDimensions(secString, fontSize);

		var x = SCREEN_SIZE / 2; // Small offset from the hours / minutes being rendered
		var y = SEC_Y;

		// Used to ensure we don't leave junk pixels behind
		if (dim[0] < secondsWidth)
		{
			dc.setClip(x - dim[0] / 2, y, secondsWidth, dim[1] - bottomMildFontCutoff + FONT_CLIP_WIGGLE);
	        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
	        dc.fillRectangle(x - dim[0] / 2, y, secondsWidth, dim[1] - bottomMildFontCutoff + FONT_CLIP_WIGGLE);
		}

		dc.setClip(x - dim[0] / 2, y, dim[0], dim[1] - bottomMildFontCutoff + FONT_CLIP_WIGGLE);
		dc.setColor(0xFFFF88, Graphics.COLOR_BLACK);		
		dc.drawText(x, y, fontSize, secString, Graphics.TEXT_JUSTIFY_CENTER);

		secondsWidth = dim[0];	
	}
    
    const CONNECTION_OFFSET_X = 10;
    const CONNECTION_OFFSET_Y = 4;
    function renderConnectionInformation(dc) {
    	if (System.getDeviceSettings().phoneConnected) {
			var verticalLocation = CALORIES_Y + CONNECTION_OFFSET_Y;
    		
    		// This character draws the connected-to-phone icon.
    		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_DK_BLUE);
    		dc.drawText(SCREEN_SIZE / 2 + CONNECTION_OFFSET_X, verticalLocation, specialCharacterFont, " : ", Graphics.TEXT_JUSTIFY_RIGHT);
    	}
    }
}