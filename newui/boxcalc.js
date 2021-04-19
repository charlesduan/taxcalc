/*
 * Computes box dimensions by expanding from a selected point.
 */
const { Point, Rectangle, Origin } = require("./point");

var context;

var maxdx = 144 * 3;
var maxdy = 72;

var imageData;
var startColor;

function setBoxBounds(dx, dy) {
    maxdx = dx;
    maxdy = dy;
}

function setCanvasContext(ctx) {
    context = ctx;
}

function computeBoxAtPoint(x, y) {
    imageData = context.getImageData(x - maxdx, y - maxdy, 2 * maxdx + 1,
        2 * maxdy + 1);
    startColor = colorAtPoint(0, 0);

    // Find the bottom edge. The number of steps taken will be coincidentally
    // equal to the y coordinate of the bottom edge.
    let ymax = advanceLine(Origin, Origin, 0, 1, maxdy);

    // Find the right edge. Again the returned number of steps will equal the x
    // coordinate.
    let xmax = advanceLine(Origin, new Point(0, ymax), 1, 0, maxdx);

    // Find the left edge.
    let xmin = -advanceLine(Origin, new Point(0, ymax), -1, 0, maxdx);

    // Find the top edge.
    let ymin = -advanceLine(new Point(xmin, 0), new Point(xmax, 0),
        0, -1, maxdy);

    // Convert back to absolute coordinates
    let res = [ x + xmin, y + ymin, x + xmax, y + ymax ];

    // Sanity checks
    if (res[0] < 0) { res[0] = 0; }
    if (res[1] < 0) { res[1] = 0; }
    if (res[2] >= context.canvas.width) { res[2] = context.canvas.width - 1; }
    if (res[3] >= context.canvas.height) { res[3] = context.canvas.height - 1; }

    return new Rectangle(new Point(res[0], res[1]), new Point(res[2], res[3]));
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
    const color = colorAtPoint(xrel, yrel);
    for (let i = 0; i < color.length; i++) {
        if (Math.abs(color[i] - startColor[i]) > 20) {
            return false;
        }
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
 * the line by (dx, dy) until the line fails to match.
 *
 * Returns the number of steps advanced before the color changed, or maxSteps if
 * it never does.
 */
function advanceLine(pMin, pMax, dx, dy, maxSteps) {
    for (let i = 1; i <= maxSteps; i++) {
        let same = sameColorForLine(pMin.x + i * dx, pMin.y + i * dy,
            pMax.x + i * dx, pMax.y + i * dy);
        if (!same) {
            return i - 1;
        }
    }
    return maxSteps;
}

module.exports = {
    setCanvasContext,
    computeBoxAtPoint,
    setBoxBounds,
};
