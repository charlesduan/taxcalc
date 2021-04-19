const gui = require("@nodegui/nodegui");
const pdfloader = require("./pdfloader");
const boxcalc = require("./boxcalc");
const { Point, Rectangle } = require("./point");
const bridge = require("./apibridge");

let resolution;

function setResolution(res) {
    resolution = res;
    boxcalc.setBoxBounds(72 * resolution * 3, 72 * resolution / 2);
}
setResolution(2);


/*
 * Construct the GUI
 */


const win = new gui.QMainWindow();
win.resize(612 * 2 + 20, 792 * 2);

const rootView = new gui.QWidget();
rootView.setLayout(new gui.FlexLayout());
rootView.setObjectName("rootView");
win.setCentralWidget(rootView);


/* Stylesheet */

rootView.setStyleSheet(`
#scrollArea {
    flex: 1;
}
#toolBar {
    height: 60px;
    flex-direction: row;
}

#container {
    background-color: blue;
    flex-direction: column;
}

#container *[line="true"] {
    background-color: yellow;
    position: absolute;
    border: 0px;
}

#container #dragWidget {
    background-color: green;
    position: absolute;
}

#toolBar QLabel {
    margin-right: 3px;
    margin-left: 12px;
}
`);


/* Toolbar */

const toolBar = new gui.QWidget();
toolBar.setObjectName("toolBar");
rootView.layout.addWidget(toolBar);
toolBar.setLayout(new gui.FlexLayout());

const formNameLabel = new gui.QLabel();
formNameLabel.setText("(No form loaded)");
toolBar.layout.addWidget(formNameLabel);

let w = new gui.QLabel();
w.setText("Page");
toolBar.layout.addWidget(w);

const pageBox = new gui.QComboBox();
toolBar.layout.addWidget(pageBox);

w = new gui.QLabel();
w.setText("Line");
toolBar.layout.addWidget(w);

const lineBox = new gui.QComboBox();
toolBar.layout.addWidget(lineBox);

w = new gui.QLabel();
w.setText("Boxed line?");
toolBar.layout.addWidget(w);

const boxLineCheck = new gui.QCheckBox();
toolBar.layout.addWidget(boxLineCheck);

const separatorLabel = new gui.QLabel();
separatorLabel.setText("Separator");
toolBar.layout.addWidget(separatorLabel);

const separatorEditor = new gui.QLineEdit();
toolBar.layout.addWidget(separatorEditor);

function hideBoxLineEditor() {
    boxLineCheck.setChecked(false);
    separatorEditor.setText("");
    separatorLabel.hide();
    separatorEditor.hide();
}

function showBoxLineEditor(text) {
    boxLineCheck.setChecked(true);
    separatorEditor.setText(text);
    separatorLabel.show();
    separatorEditor.show();
}

showBoxLineEditor();


/*
 * Helper functions for converting the toolbar information to an API exportable
 * object.
 */

function toolbarInfo() {
    const res = {
        line: lineBox.currentText(),
        boxed: boxLineCheck.isChecked(),
        separator: separatorEditor.text(),
    };
    return res;
}

let updatingToolbar = false;

function setToolbarInfo(obj) {
    updatingToolbar = true;
    lineBox.setCurrentText(obj.line);
    if (obj.boxed) {
        showBoxLineEditor(obj.separator);
    } else {
        hideBoxLineEditor();
    }
    updatingToolbar = false;
}

/*
 * Event handlers for toolbar
 */

function sendToolbarUpdate() {
    if (updatingToolbar) { return; }
    bridge.send("toolbarUpdate", toolbarInfo());
}
lineBox.addEventListener("currentTextChanged", (evt) => sendToolbarUpdate());
boxLineCheck.addEventListener("clicked", (evt) => sendToolbarUpdate());
separatorEditor.addEventListener("textChanged", (evt) => sendToolbarUpdate());

pageBox.addEventListener('currentIndexChanged',
    async index => selectPage(index + 1));



/* Main PDF display */

const scrollArea = new gui.QScrollArea(win);
scrollArea.setObjectName("scrollArea");

rootView.layout.addWidget(scrollArea);

var pdfContainer;

function makeContainer() {
    let startPoint, endPoint, dragWidget;
    pdfContainer = new gui.QWidget();
    pdfContainer.setLayout(new gui.FlexLayout(0));
    pdfContainer.setObjectName("container");

    scrollArea.setWidget(pdfContainer);

    /*
     * Event handlers for the scroll area, to respond to double-clicks and
     * drags.
     */

    pdfContainer.addEventListener(
        gui.WidgetEventTypes.MouseButtonDblClick,
        (evt) => {
            const mouseEvt = new gui.QMouseEvent(evt);
            addLineBox(boxcalc.computeBoxAtPoint(mouseEvt.x(), mouseEvt.y()));
        }
    );

    pdfContainer.addEventListener(
        gui.WidgetEventTypes.MouseButtonPress,
        (evt) => {
            const mouseEvt = new gui.QMouseEvent(evt);
            if (mouseEvt.button() != 1) {
                startPoint = undefined;
                return;
            }
            startPoint = new Point(mouseEvt.x(), mouseEvt.y());
        }
    );

    pdfContainer.addEventListener(
        gui.WidgetEventTypes.MouseMove,
        (evt) => {
            if (startPoint === undefined) { return; }
            const mouseEvt = new gui.QMouseEvent(evt);
            endPoint = new Point(mouseEvt.x(), mouseEvt.y());
            if (dragWidget === undefined) {
                dragWidget = new gui.QLabel();
                dragWidget.setObjectName("dragWidget");
                pdfContainer.layout.addWidget(dragWidget);
            }
            const rect = new Rectangle(startPoint, endPoint);
            rect.setWidgetPos(dragWidget);
        }
    );

    pdfContainer.addEventListener(
        gui.WidgetEventTypes.MouseButtonRelease,
        (evt) => {
            if (dragWidget === undefined) { return; }
            const mouseEvt = new gui.QMouseEvent(evt);
            endPoint = new Point(mouseEvt.x(), mouseEvt.y());
            const rect = new Rectangle(startPoint, endPoint);
            pdfContainer.layout.removeWidget(dragWidget);
            dragWidget.hide();
            dragWidget = undefined;
            addLineBox(rect);
        }
    );

}

/*
 * Functions
 */

async function loadPdf(filename, formname, lines) {
    numPages = await pdfloader.loadPdf(filename);
    pageBox.clear();
    formNameLabel.setText('' + formname + " (" + filename + ")")
    for (var i = 1; i <= numPages; i++) {
        pageBox.addItem(undefined, "Page " + i.toString());
    }
    lineBox.clear();
    lineBox.addItems(lines);
}

async function selectPage(page) {
    // TODO: Should invalidate the current image
    makeContainer();
    const canvas = await pdfloader.selectPage(page, resolution);
    const buffer = canvas.toBuffer();
    boxcalc.setCanvasContext(canvas.getContext('2d'));
    const image = new gui.QPixmap();
    const pdfDisplay = new gui.QLabel();
    image.loadFromData(buffer, "PNG");
    pdfDisplay.setPixmap(image);
    pdfContainer.layout.addWidget(pdfDisplay);
    pdfContainer.resize(image.width() + 50, image.height() + 50);
    bridge.send("selectPage", { page });
}

function addLineBox(rect) {
    bridge.send("addLineBox", {
        toolbar: toolbarInfo(),
        pos: rect.toJSON(),
    });
}

const lineBoxes = {};

function drawLineBox(text, id, rect) {
    const label = new gui.QPushButton(pdfContainer);
    label.setText(text);
    label.setProperty("line", true);
    rect.setWidgetPos(label);
    label.addEventListener(
        gui.WidgetEventTypes.MouseButtonDblClick,
        (evt) => bridge.send("removeLine", { id })
    );
    pdfContainer.layout.addWidget(label);

    // Should not happen in production; the box should already have been removed
    if (lineBoxes[id]) {
        console.log(`Adding line box ${id} that already exists`);
        removeLineBox(id);
    }
    lineBoxes[id] = label;
}

function removeLineBox(id) {
    const label = lineBoxes[id];
    if (label) {
        pdfContainer.layout.removeWidget(label);
        label.hide();
        delete lineBoxes[id];
    }
}

function execute(command, payload) {
    console.log("Recv: " + command + ", " + JSON.stringify(payload, null, 2));
    switch (command) {
        case "drawLineBox":
            drawLineBox(payload.line, payload.id,
                new Rectangle(...payload.pos));
            break;
        case "removeLineBox":
            removeLineBox(payload.id);
            break;
        case "setToolbarInfo":
            setToolbarInfo(payload);
            break;
    }
}
bridge.setHandler(execute);

/*
 * Export modules
 */

module.exports = {
    loadPdf,
    setToolbarInfo,
}

/*
 * Show the window
 */

win.show();
global.win = win;

