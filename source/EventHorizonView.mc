import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time.Gregorian;
import Toybox.Math;

class EventHorizonView extends WatchUi.WatchFace {

    private var _centerX as Number = 0;
    private var _centerY as Number = 0;
    private var _radius as Number = 0;
    private var _electricBlue as Number = 0x00FFFF; // Cyan/Electric Blue
    private var _shieldColor as Number = 0x000000; // Black
    private var _handColor as Number = 0xAAAAAA; // Silver/Grey
    private var _secondHandColor as Number = 0x00FFFF; // Electric Blue tip? Or just silver. Let's go with silver/grey for main, blue tip maybe.
    private var _isInSleepMode as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _centerX = dc.getWidth() / 2;
        _centerY = dc.getHeight() / 2;
        _radius = (_centerX < _centerY ? _centerX : _centerY) - 20;

    }

    function onUpdate(dc as Dc) as Void {
        // Clear screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_isInSleepMode) {
            // In sleep mode, only draw the hands (no seconds)
            drawHands(dc, true);
            return;
        }

        //Other Background
        drawConcentricBackground(dc);
        drawStarField(dc);


        // Draw the Shield Shape
        drawShieldBackground(dc);

        // Draw the Electric Blue Circuit Lines
        drawCircuitLines(dc);

        // Draw the Logo
        drawLogo(dc);

        // Draw Hands
        drawHands(dc, false);
    }


    private function drawConcentricBackground(dc as Dc) as Void {
        // Couleurs du dégradé du plus foncé au plus clair
        var colors = [
            0x000510, // Centre: Bleu très très sombre
            0x000A18,
            0x001020,
            0x001528,
            0x001A30,
            0x002038,
            0x002540,
            0x003048,
            0x003550,
            0x004060  // Extérieur: Bleu nuit plus clair
        ];
        var maxRadius = _radius + 20;
        var numRings = colors.size();
        
        // Dessiner les cercles concentriques du plus grand au plus petit
        for (var i = numRings - 1; i >= 0; i--) {
            var ringRadius = maxRadius * (i + 1) / numRings;
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_centerX, _centerY, ringRadius);
        }
    }

    private function drawStarField(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // Vous pouvez ajuster le nombre d'étoiles ici
        var numStars = 200;
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Utilise une graine (seed) constante pour que le champ d'étoiles soit
        // identique à chaque appel. C'est un simple générateur pseudo-aléatoire.
        var seed = 1;

        for (var i = 0; i < numStars; i++) {
            // Génère une coordonnée X pseudo-aléatoire
            seed = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
            var x = seed % width;

            // Génère une coordonnée Y pseudo-aléatoire
            seed = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
            var y = seed % height;

            // Fait varier la taille des étoiles pour un effet plus naturel
            // 30% des étoiles seront un peu plus grandes.
            seed = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
            var size = (seed % 10 > 7) ? 2 : 1;

            dc.fillCircle(x, y, size);
        }
    }


    private function drawShieldBackground(dc as Dc) as Void {
        // The Ventura shape is a triangle with curved sides.
        // Since the screen is round, we want to maximize the size but keep the shape visible.
        // We'll draw a polygon or fill the background black (already done).
        // To make it look like the watch, we might want to draw a dark grey outline of the shield if the background is black.
        // But the user asked for the watch face.
        // Let's assume the whole screen is the "face" but we draw the shield contour to define the active area.
        
        // Actually, looking at the image, the face IS the shield. The rest is the strap/case.
        // On a round watch, we can't change the physical shape.
        // So we will draw the shield shape in the center.
        
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Coordinates for a shield shape
        // Top Left, Top Right, Bottom Center (roughly)
        // It's an asymmetric triangle? No, Ventura is usually symmetric or slightly asymmetric depending on model.
        // The image shows a symmetric shield rotated 90 degrees? No, it's a triangle pointing down/right?
        // Wait, the image shows the Ventura Elvis80 or similar. It's a triangle pointing roughly 3 o'clock?
        // No, the crown is on the right. The point is on the left?
        // Let's look at the image again.
        // The top is wide, the bottom is a point. It's a triangle pointing down.
        // But it's rotated. The 12 is at the top.
        // The shape is: Top edge is curved. Sides are curved to a point at the bottom.
        // Actually, the Ventura is often "shield" shaped on its side.
        // In the image provided:
        // The 12 o'clock marker is at the top.
        // The shape is roughly a triangle with the base at the top-left to bottom-left?
        // No, let's look at the markers.
        // There is a marker at 12 (top), 6 (bottom), 9 (left).
        // The "point" seems to be at the 3 o'clock position (right) or 9 o'clock?
        // The Hamilton Ventura is unique.
        // Let's assume a standard orientation where 12 is up.
        // The image shows the case is triangular.
        // The dial inside follows the case.
        // I will draw a "Shield" shape that fits within the circle.
        
        // Let's define points for a polygon that approximates the shield.
        // Top-Left, Top-Right, Bottom.
        // Top edge is convex.
        // Side edges are convex.
        
        // For simplicity and "best effort" on a round screen:
        // I will draw the "Electric Blue" pattern which DEFINES the look more than the black background on black.
        
    }

    private function drawCircuitLines(dc as Dc) as Void {
        dc.setColor(_electricBlue, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);

        // The pattern in the image:
        // A central circle/arc structure on the left (9 o'clock).
        // Lines radiating out or forming a grid.
        // "Hamilton" text on the right.
        
        // Let's approximate the "pulse" design.
        // It looks like a zig-zag or frequency wave on the left, scaling from 9 o'clock towards the center.
        
        // Left side (9 o'clock) - The "Generator" look
        // Concentric arcs or a spiral?
        // Image shows: A circle at 9 o'clock.
        // Then lines extending to the right.
        
        var r = _centerX; // radius
        
        // 1. The Circle at 9 o'clock
        var circleX = _centerX - r * 0.5;
        var circleY = _centerY;
        var circleRadius = r * 0.15;
        
        dc.setPenWidth(3);
        dc.drawCircle(circleX, circleY, circleRadius);
        dc.fillCircle(circleX, circleY, circleRadius * 0.4); // Inner dot
        
        // 2. Arcs around it
        dc.drawArc(circleX, circleY, circleRadius * 1.5, Graphics.ARC_COUNTER_CLOCKWISE, 270, 90);
        dc.drawArc(circleX, circleY, circleRadius * 2.0, Graphics.ARC_COUNTER_CLOCKWISE, 250, 110);
        
        // 3. The "Wings" / Lines extending to the right
        // Top Wing
        var startX = circleX + circleRadius * 1.5; // Approximate
        var startY = circleY - circleRadius * 1.0;
        
        // Draw a shape that looks like the top trapezoid/wing
        // Lines: Start near 9 o'clock, go up-right, then right, then down-right?
        // Let's try to draw the outline of the blue shapes.
        
        // Top Shape
        var topPts = [
            [(_centerX - 40), (_centerY - 10)],
            [(_centerX - 20), (_centerY - 60)],
            [(_centerX + 60), (_centerY - 50)],
            [(_centerX + 80), (_centerY - 10)]
        ];
        // This is hard to guess coordinates. I'll make a symmetric pattern.
        
        // Let's try to replicate the image's "Electric" feel.
        // It has a horizontal symmetry axis (roughly).
        
        // Top Blue Loop
        dc.drawLine(_centerX - 50, _centerY - 15, _centerX - 40, _centerY - 60); // Left up
        dc.drawLine(_centerX - 40, _centerY - 60, _centerX + 60, _centerY - 50); // Top across
        dc.drawLine(_centerX + 60, _centerY - 50, _centerX + 50, _centerY - 15); // Right down
        dc.drawLine(_centerX + 50, _centerY - 15, _centerX - 50, _centerY - 15); // Bottom across (close loop)
        
        // Bottom Blue Loop (Mirrored)
        dc.drawLine(_centerX - 50, _centerY + 15, _centerX - 40, _centerY + 60); 
        dc.drawLine(_centerX - 40, _centerY + 60, _centerX + 60, _centerY + 50); 
        dc.drawLine(_centerX + 60, _centerY + 50, _centerX + 50, _centerY + 15); 
        dc.drawLine(_centerX + 50, _centerY + 15, _centerX - 50, _centerY + 15); 
        
        // Connecting lines to the circle on the left
        dc.drawLine(_centerX - 50, _centerY - 15, circleX + circleRadius, _centerY - 5);
        dc.drawLine(_centerX - 50, _centerY + 15, circleX + circleRadius, _centerY + 5);
        
        // 4. Hour Markers (Indices)
        // The image shows markers at 12, 1, 2, 4, 5, 6, 7, 8, 10, 11
        // They are simple white lines.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var markerRadius = _centerX * 0.9;
        var markerLen = 15;
        
        for (var i = 0; i < 12; i++) {
            // Skip 3 and 9 if they are covered by design? 
            // Image shows 9 is covered by the circle. 3 is the point of the shield?
            if (i == 3 || i == 9) { continue; }
            
            var angle = (i / 12.0) * Math.PI * 2 - Math.PI / 2;
            var x1 = _centerX + markerRadius * Math.cos(angle);
            var y1 = _centerY + markerRadius * Math.sin(angle);
            var x2 = _centerX + (markerRadius - markerLen) * Math.cos(angle);
            var y2 = _centerY + (markerRadius - markerLen) * Math.sin(angle);
            
            dc.drawLine(x1, y1, x2, y2);
        }
    }

    private function drawLogo(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // "HAMILTON" text on the right side, centered vertically between the blue loops?
        // In the image, it's centered in the middle right.
        
        //dc.drawText(_centerX + 20, _centerY, Graphics.FONT_XTINY, "HAMILTON", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawHands(dc as Dc, inSleep as Boolean) as Void {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var min = clockTime.min;
        var sec = clockTime.sec;

        // Adjust for 12-hour format if needed, but math works with 24h too for angle
        var hourAngle = ((hour % 12) * 60 + min) / (12 * 60.0) * Math.PI * 2 - Math.PI / 2;
        var minAngle = min / 60.0 * Math.PI * 2 - Math.PI / 2;
        var secAngle = sec / 60.0 * Math.PI * 2 - Math.PI / 2;

        // Draw Hour Hand
        // Dauphine style hands (triangular)
        // drawDauphineHand(dc, hourAngle, 60, 6, _handColor); // ORIGINAL
        drawDauphineHand(dc, hourAngle, 70, 8, _handColor); // MODIFIED: Increased size

        // Draw Minute Hand
        // drawDauphineHand(dc, minAngle, 90, 4, _handColor); // ORIGINAL
        drawDauphineHand(dc, minAngle, 100, 6, _handColor); // MODIFIED: Increased size

        // Draw Second Hand
        // Thin line with a tip
        if (!inSleep) {
            // var secRadius = 90; // ORIGINAL
            var secRadius = 100; // MODIFIED: Increased size
            var x = _centerX + secRadius * Math.cos(secAngle);
            var y = _centerY + secRadius * Math.sin(secAngle);
            //dc.setColor(_electricBlue, Graphics.COLOR_TRANSPARENT);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            // dc.setPenWidth(2); // ORIGINAL
            dc.setPenWidth(3); // MODIFIED: Increased size
            dc.drawLine(_centerX, _centerY, x, y);
            // dc.fillCircle(x, y, 3); // Tip // ORIGINAL
            dc.fillCircle(x, y, 4); // Tip // MODIFIED: Increased size
        }
    }

    private function drawDauphineHand(dc as Dc, angle as Float, length as Number, width as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        
        // Calculate polygon points for a diamond/dauphine shape
        // Center, Tip, Back-Left, Back-Right
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);
        
        // Tip
        var xTip = _centerX + length * cos;
        var yTip = _centerY + length * sin;
        
        // Base (slightly behind center)
        var backLen = 15;
        var xBack = _centerX - backLen * cos;
        var yBack = _centerY - backLen * sin;
        
        // Side points (perpendicular to angle)
        var xSide1 = _centerX + width * Math.sin(angle);
        var ySide1 = _centerY - width * Math.cos(angle);
        var xSide2 = _centerX - width * Math.sin(angle);
        var ySide2 = _centerY + width * Math.cos(angle);
        
        var points = [
            [xTip, yTip],
            [xSide1, ySide1],
            [xBack, yBack],
            [xSide2, ySide2]
        ];
        
        dc.fillPolygon(points);
        
        // Draw a central line for detail?
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(_centerX, _centerY, xTip, yTip);
    }

    function onHide() as Void {
    }

    function onEnterSleep() as Void {
        _isInSleepMode = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _isInSleepMode = false;
        WatchUi.requestUpdate();
    }

}
