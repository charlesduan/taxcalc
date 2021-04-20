class Point {
    constructor(x, y) {
        this.x = x;
        this.y = y;
    }

    plus(x, y) {
        if (y === undefined) {
            return new Point(this.x + x.x, this.y + x.y);
        } else {
            return new Point(this.x + x, this.y + y);
        }
    }

    times(s) {
        return new Point(this.x * s, this.y * s);
    }

    leq(x, y) {
        if (y === undefined) {
            return (this.x <= x.x && this.y <= x.y);
        } else {
            return (this.x <= x && this.y <= y);
        }
    }

    /*
     * Computes the next point toward a point greater than or equal to this one,
     * first by incrementing the x coordinate and then by incrementing the y.
     */
    nextToward(p) {
        if (p.x > this.x) { return new Point(this.x + 1, this.y); }
        if (p.y > this.y) { return new Point(this.x, this.y + 1); }
        return null;
    }

    toString() {
        return `(${this.x}, ${this.y})`;
    }
}

class Rectangle {
    constructor(...args) {
        let p1, p2;
        if (args.length == 4) {
            p1 = new Point(args[0], args[1]);
            p2 = new Point(args[2], args[3]);
        } else {
            p1 = args[0];
            p2 = args[1];
        }
        this.min = new Point(Math.min(p1.x, p2.x), Math.min(p1.y, p2.y));
        this.max = new Point(Math.max(p1.x, p2.x), Math.max(p1.y, p2.y));
    }
    get width() {
        return this.max.x - this.min.x;
    }
    get height() {
        return this.max.y - this.min.y;
    }

    times(s) {
        return new Rectangle(this.min.times(s), this.max.times(s));
    }

    /*
     * For a split line, the box that follows this is assumed to contain the
     * point returned by this method.
     */
    nextSplitStartPoint() {
        return new Point(
            this.max.x + this.width() / 3,
            (this.min.y + this.max.y) / 2
        );
    }

    setWidgetPos(widget) {
        widget.setInlineStyle(
            "left: " + this.min.x + "px; " +
            "top: " + this.min.y + "px; " +
            "min-width: " + this.width + "px; " +
            "max-width: " + this.width + "px; " +
            "min-height: " + this.height + "px; " +
            "max-height: " + this.height + "px; "
        );
    }

    toJSON(key) {
        return [ this.min.x, this.min.y, this.max.x, this.max.y ]
    }
}

const Origin = new Point(0, 0);

module.exports = {
    Point,
    Rectangle,
    Origin,
}

