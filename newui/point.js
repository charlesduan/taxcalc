class Point {
    constructor(x, y) {
        this.x = x;
        this.y = y;
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

