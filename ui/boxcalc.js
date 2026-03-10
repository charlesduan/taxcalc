/*
 * Computes box dimensions by expanding from a selected point.
 */
const { Point, Rectangle, Origin } = require("./point");

var context;

var maxdx = 144 * 3;
var maxdy = 72;

var imageData;

function setBoxBounds(dx, dy) {
    maxdx = dx;
    maxdy = dy;
}

function setCanvasContext(ctx) {
    context = ctx;
    imageData = context.getImageData(0, 0,
        context.canvas.width, context.canvas.height);
}

function computeBoxAtPoint(point) {

    const p = new Point(Math.round(point.x), Math.round(point.y));

    if (p.x < 0 || p.y < 0
        || p.x >= context.canvas.width || p.y >= context.canvas.height) {
        return undefined;
    }

    // Find the bottom edge.
    let ymax = p.plus(advanceLine(p, p, new Point(0, 1), maxdy));

    // Find the right edge.
    let xmax = p.plus(advanceLine(p, ymax, new Point(1, 0), maxdx));

    // Find the left edge.
    let xmin = p.plus(advanceLine(p, ymax, new Point(-1, 0), maxdx));

    // Recalculate the left and right edge, based just on the bottom line. Use
    // If the bottom line distance is reasonable, use whichever values lead to a
    // smaller box.
    let ybot = ymax.plus(0, 2);
    let xbotmax = ymax.plus(advanceLine(ybot, ybot, new Point(1, 0), maxdx));
    let xbotmin = ymax.plus(advanceLine(ybot, ybot, new Point(-1, 0), maxdx));
    let xbotdiff = xbotmax.x - xbotmin.x;
    if (xbotdiff > 20) {
        if (xmax.x > xbotmax.x) { xmax = xbotmax; }
        if (xmin.x < xbotmin.x) { xmin = xbotmin; }
    }

    // Find the top edge.
    let ymin = p.plus(advanceLine(
        new Point(xmin.x, p.y), new Point(xmax.x, p.y),
        new Point(0, -1), maxdy)
    );

    // Convert back to absolute coordinates
    let res = [ xmin.x, ymin.y, xmax.x, ymax.y ];

    // Sanity checks
    if (res[0] < 0) { res[0] = 0; }
    if (res[1] < 0) { res[1] = 0; }
    if (res[2] >= context.canvas.width) { res[2] = context.canvas.width - 1; }
    if (res[3] >= context.canvas.height) { res[3] = context.canvas.height - 1; }

    const r = new Rectangle(...res);
    return r;
}

/*
 * Returns the color at the given point. The point is given relative to an
 * origin that is the user's specified point.
 */
function colorAt(p) {
    if (p.x < 0 || p.y < 0
        || p.x >= imageData.width || p.y >= imageData.height) {
        return [ -100, -100, -100, -100 ];
    }
    const index = (p.y * imageData.width + p.x) * 4;
    return imageData.data.subarray(index, index + 3);
}

/*
 * Tests if the colors of two given points match.
 */
function sameColor(p1, p2) {
    const c1 = colorAt(p1), c2 = colorAt(p2);
    //console.log("Color at " + p1 + ": " + c1 + "; color at " + p2 + ": " + c2);
    for (let i = 0; i < 3; i++) {
        if (Math.abs(c1[i] - c2[i]) > 10) {
            return false;
        }
    }
    return true;
}

/*
 * Starting from the given line, advance the line by delta until the line
 * fails to match the original line.
 *
 * Returns the total displacement found (delta * number of steps taken).
 */
function advanceLine(pMin, pMax, delta, maxSteps) {
    for (let i = 1; i <= maxSteps; i++) {
        let totalDelta = delta.times(i);
        // The edges must match exactly.
        if (!sameColor(pMin, pMin.plus(totalDelta))) {
            return delta.times(i - 1);
        }
        if (!sameColor(pMax, pMax.plus(totalDelta))) {
            return delta.times(i - 1);
        }

        // Otherwise we check for a threshold error.
        let errs = 0;
        let count = 0;
        for (let pIter = pMin; pIter !== null; pIter = pIter.nextToward(pMax)) {
            count += 1;
            if (!sameColor(pIter, pIter.plus(totalDelta))) { errs += 1; }
        }
        if (errs > 5 || errs * 1.0 / count > 0.1) { return delta.times(i - 1); }
    }
    return delta.times(maxSteps);
}

module.exports = {
    setCanvasContext,
    computeBoxAtPoint,
    setBoxBounds,
    sameColor,
};
