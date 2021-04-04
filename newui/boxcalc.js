/*
 * Computes box dimensions by expanding from a selected point.
 */

var context;

var maxdx = 72;
var maxdy = 144 * 3;

var imageData;
var startColor;

function setCanvasContext(ctx) {
    context = ctx;
}

function computeBoxAtPoint(x, y) {
    imageData = context.getImageData(x - maxdx, y - maxdy, 2 * maxdx + 1,
        2 * maxdy + 1);
    startColor = colorAtPoint(0, 0);
}

/*
 * Returns the color at the given point. The point is given relative to an
 * origin that is the user's specified point.
 */
function colorAtPoint(xrel, yrel) {
    const index = ((yrel + maxdy) * imageData.width + xrel + maxdx) * 4;
    return imageData.data.subarray(index, index + 3);
}

/*
 * Tests if the color of the given point matches the color at the origin.
 */
function sameColorAtPoint(xrel, yrel) {
    var color = colorAtPoint(xrel, yrel);
    for (let i = 0; i < color.length; i++) {
        if (Math.abs(color[i] - startColor[i]) > 20) { return false; }
    }
    return true;
}

/*
 * Determines if the color for each point on the given line matches the
 * startColor. The line must be horizontal or vertical.
 */
function sameColorForLine(xrelMin, yrelMin, xrelMax, yrelMax) {
    if (xrelMin == xrelMax) {
        for (let yrel = yrelMin; yrel <= yrelMax; yrel++) {
            if (!sameColorAtPoint(xrelMin, yrel)) { return false; }
        }
    } else {
        for (let xrel = xrelMin; xrel <= xrelMax; xrel++) {
            if (!sameColorAtPoint(xrel, yrelMin)) { return false; }
        }
    }
    return true;
}

/*
 * Starting from the given line, which is assumed to match startColor, advance
 * the line in a perpendicular direction given by dir, until the line's color
 * fails to match.
 *
 * Returns the value of the coordinate that moved as the line advanced.
 */
function advanceLine(xrelMin, yrelMin, xrelMax, yrelMax, dir, maxSteps) {
    if (xrelMin == xrelMax) {
        xrel = xrelMin;
        for (let i = 0; i < maxSteps; i++) {
            xrel += dir;
            if (!sameColorForLine(xrel, yrelMin, xrel, yrelMax)) {
                return xrel - dir;
            }
        }
        return xrel;
    } else {
        yrel = yrelMin;
        for (let i = 0; i < maxSteps; i++) {
            yrel += dir;
            if (!sameColorForLine(xrelMin, yrel, xrelMax, yrel)) {
                return yrel - dir;
            }
        }
        return yrel;
    }
}

module.exports = {
    setCanvasContext,
    computeBoxAtPoint,
};
