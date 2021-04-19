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

function computeBoxAtPoint(x, y) {

    console.log(`Starting at (${x}, ${y})`);


    let origin = new Point(x, y);
    console.log(`Color at ${origin} is ${colorAt(origin)}`);

    // Find the bottom edge. The number of steps taken will be coincidentally
    // equal to the y coordinate of the bottom edge.
    let ymax = origin.plus(advanceLine(origin, origin, new Point(0, 1), maxdy));
    console.log(`ymax is ${ymax}`);
    ymax = ymax.plus(0, 1); // Collect the bottom line for testing too

    // Find the right edge. Again the returned number of steps will equal the x
    // coordinate.
    let xmax = origin.plus(advanceLine(origin, ymax, new Point(1, 0), maxdx));
    console.log(`xmax is ${xmax}`);

    // Find the left edge.
    let xmin = origin.plus(advanceLine(origin, ymax, new Point(-1, 0), maxdx));
    console.log(`xmin is ${xmin}`);

    // Find the top edge.
    let ymin = origin.plus(advanceLine(xmin, xmax, new Point(0, -1), maxdy));
    console.log(`ymin is ${ymin}`);

    // Convert back to absolute coordinates
    let res = [ xmin.x, ymin.y, xmax.x, ymax.y - 1 ];

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
    for (let i = 0; i < 3; i++) {
        if (Math.abs(c1[i] - c2[i]) > 20) {
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
        for (let pIter = pMin; pIter !== null; pIter = pIter.nextToward(pMax)) {
            if (!sameColor(pIter, pIter.plus(totalDelta))) {
                return delta.times(i - 1);
            }
        }
    }
    return delta.times(i);
}

module.exports = {
    setCanvasContext,
    computeBoxAtPoint,
    setBoxBounds,
};
