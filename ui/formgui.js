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
 * Cache of all the boxes on the current page.
 */
let lineBoxes = {};


/*
 * Construct the GUI
 */


const win = new gui.QMainWindow();
win.resize(612 * 2 + 20, 1000);

win.addEventListener(gui.WidgetEventTypes.Close,
    (evt) => { bridge.shutdown(); });

const rootView = new gui.QWidget();
const rootLayout = new gui.FlexLayout();
rootLayout.setFlexNode(rootView.getFlexNode());
rootView.setLayout(rootLayout);
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

#pageSelector {
    width: 60px;
}

#lineSelector {
    width: 300px;
}

#container {
    background-color: blue;
    flex-direction: column;
}

#container *[line="true"] {
    background-color: yellow;
    position: absolute;
    border: 0px;
    margin: 0px;
    padding: 0px;
}

#container *[line="true"]:hover {
    border: 2px solid red;
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
const toolBarLayout = new gui.FlexLayout();
toolBarLayout.setFlexNode(toolBar.getFlexNode());
toolBar.setLayout(toolBarLayout);
toolBar.setObjectName("toolBar");
rootLayout.addWidget(toolBar);

const formNameLabel = new gui.QLabel();
formNameLabel.setText("(No form loaded)");
toolBarLayout.addWidget(formNameLabel);

let w = new gui.QLabel();
w.setText("Page");
toolBarLayout.addWidget(w);

const prevPageButton = new gui.QPushButton();
prevPageButton.setText("<");
toolBarLayout.addWidget(prevPageButton);

const pageSelector = new gui.QComboBox();
pageSelector.setObjectName("pageSelector");
toolBarLayout.addWidget(pageSelector);

const nextPageButton = new gui.QPushButton();
nextPageButton.setText(">");
toolBarLayout.addWidget(nextPageButton);

w = new gui.QLabel();
w.setText("Line");
toolBarLayout.addWidget(w);

const lineSelector = new gui.QComboBox();
lineSelector.setObjectName("lineSelector");
toolBarLayout.addWidget(lineSelector);

w = new gui.QLabel();
w.setText("Split line?");
toolBarLayout.addWidget(w);

const splitLineCheck = new gui.QCheckBox();
toolBarLayout.addWidget(splitLineCheck);

const splitSepLabel = new gui.QLabel();
splitSepLabel.setText("Split Separator");
toolBarLayout.addWidget(splitSepLabel);

const splitSepEditor = new gui.QLineEdit();
toolBarLayout.addWidget(splitSepEditor);

function hideSplitEditor() {
    splitLineCheck.setChecked(false);
    splitSepEditor.setText("");
    splitSepEditor.hide();
    splitSepLabel.hide();
}

function showSplitEditor(text) {
    splitLineCheck.setChecked(true);
    splitSepEditor.setText(text);
    splitSepEditor.show();
    splitSepLabel.show();
}

hideSplitEditor();


/*
 * Helper functions for converting the toolbar information to an API exportable
 * object.
 */

function toolbarInfo() {
    const res = {
        line: lineSelector.currentText(),
        split: splitLineCheck.isChecked(),
        separator: splitSepEditor.text(),
    };
    return res;
}

let updatingToolbar = false;

function setToolbarInfo(obj) {
    updatingToolbar = true;
    if ('line' in obj) { lineSelector.setCurrentText(obj.line); }
    if ('split' in obj) {
        if (obj.split) {
            showSplitEditor(obj.separator);
        } else {
            hideSplitEditor();
        }
    }
    updatingToolbar = false;
}

/*
 * Event handlers for toolbar
 */

function sendToolbarUpdate(cmd) {
    if (updatingToolbar) { return; }
    bridge.send(cmd, toolbarInfo());
}
lineSelector.addEventListener("currentTextChanged",
    (evt) => sendToolbarUpdate("lineChanged"));
splitLineCheck.addEventListener("clicked",
    (evt) => sendToolbarUpdate("splitChanged"));
splitSepEditor.addEventListener("textChanged",
    (evt) => sendToolbarUpdate("splitSepChanged"));

pageSelector.addEventListener('currentIndexChanged',
    async index => displayPage());
prevPageButton.addEventListener('clicked', (evt) => {
    try {
        const newPage = Math.max(0, pageSelector.currentIndex() - 1)
        pageSelector.setCurrentIndex(newPage);
    } catch (e) { console.log(e); }
});
nextPageButton.addEventListener('clicked', (evt) => {
    try {
        const newPage = Math.min(
            pageSelector.currentIndex() + 1, pdfloader.numPages() - 1
        );
        pageSelector.setCurrentIndex(newPage);
    } catch (e) { console.log(e); }
});




/* Main PDF display */

const scrollArea = new gui.QScrollArea(win);
scrollArea.setObjectName("scrollArea");

rootLayout.addWidget(scrollArea);

var pdfContainer;
var pdfContainerLayout;

function makeContainer() {
    let startPoint, endPoint, dragWidget;
    pdfContainer = new gui.QWidget();
    pdfContainerLayout = new gui.FlexLayout(0);
    pdfContainerLayout.setFlexNode(pdfContainer.getFlexNode());
    pdfContainer.setLayout(pdfContainerLayout);
    pdfContainer.setObjectName("container");

    scrollArea.setWidget(pdfContainer);

    /*
     * Event handlers for the scroll area, to respond to double-clicks and
     * drags.
     */

    pdfContainer.addEventListener(
        gui.WidgetEventTypes.MouseButtonDblClick,
        (evt) => { try {
            const mouseEvt = new gui.QMouseEvent(evt);
            const boxRect = boxcalc.computeBoxAtPoint(
                new Point(mouseEvt.x(), mouseEvt.y())
            );
            if (boxRect) { addLineBox(boxRect); }
        } catch (e) { console.log(e); } }
    );

    pdfContainer.addEventListener(
        gui.WidgetEventTypes.MouseButtonPress,
        (evt) => { try {
            const mouseEvt = new gui.QMouseEvent(evt);
            if (mouseEvt.button() != 1) {
                startPoint = undefined;
                return;
            }
            startPoint = new Point(mouseEvt.x(), mouseEvt.y());
        } catch (e) { console.log(e); } }
    );

    pdfContainer.addEventListener(
        gui.WidgetEventTypes.MouseMove,
        (evt) => { try {
            if (startPoint === undefined) { return; }
            const mouseEvt = new gui.QMouseEvent(evt);
            endPoint = new Point(mouseEvt.x(), mouseEvt.y());
            if (dragWidget === undefined) {
                dragWidget = new gui.QLabel();
                dragWidget.setObjectName("dragWidget");
                pdfContainerLayout.addWidget(dragWidget);
            }
            const rect = new Rectangle(startPoint, endPoint);
            rect.setWidgetPos(dragWidget);
        } catch (e) { console.log(e); } }
    );

    pdfContainer.addEventListener(
        gui.WidgetEventTypes.MouseButtonRelease,
        (evt) => { try {
            if (dragWidget === undefined) { return; }
            const mouseEvt = new gui.QMouseEvent(evt);
            endPoint = new Point(mouseEvt.x(), mouseEvt.y());
            const rect = new Rectangle(startPoint, endPoint);
            pdfContainerLayout.removeWidget(dragWidget);
            dragWidget.hide();
            dragWidget = undefined;
            addLineBox(rect);
        } catch (e) { console.log(e); } }
    );

}

/*
 * Functions
 */

async function loadPdf(formname, filename, lines) {
    updatingToolbar = true;
    lineSelector.clear();
    lineSelector.addItems(lines);
    updatingToolbar = false;

    await pdfloader.loadPdf(filename);
    const numPages = pdfloader.numPages();
    pageSelector.clear();
    formNameLabel.setText('Form ' + formname)
    for (var i = 1; i <= numPages; i++) {
        pageSelector.addItem(undefined, i.toString());
    }
}

/*
 * Returns the number of the currently selected page, 1-indexed.
 */
function currentPage() {
    return pageSelector.currentIndex() + 1;
}

/*
 * Changes the scroll UI element to display the currently selected page. Also
 * notifies the API bridge of the page change, so that the controller can inform
 * the UI which boxes to draw on the page.
 *
 * This method is called when the page selector changes.
 */
async function displayPage() {
    try {
        const page = currentPage();
        lineBoxes = {}; // Invalidate all the current boxes
        makeContainer();
        const canvas = await pdfloader.selectPage(page, resolution);
        const buffer = canvas.toBuffer();
        boxcalc.setCanvasContext(canvas.getContext('2d'));
        const image = new gui.QPixmap();
        const pdfDisplay = new gui.QLabel();
        image.loadFromData(buffer, "PNG");
        pdfDisplay.setPixmap(image);
        pdfContainerLayout.addWidget(pdfDisplay);
        pdfContainer.resize(image.width(), image.height());

        bridge.send("selectPage", { page });
    } catch (e) {
        console.log(e);
    }
}

function addLineBox(rect, info = null) {
    bridge.send("addLineBox", {
        toolbar: info || toolbarInfo(),
        page: currentPage(),
        pos: rect.times(1 / resolution).toJSON(),
    });
}

function drawLineBox(id, page, pos) {
    if (page != currentPage()) { return; } // Avoid synchronization issue
    const label = new gui.QPushButton(pdfContainer);
    label.setFlat(true);
    label.setText(id);
    label.setProperty("line", true);
    const rect = new Rectangle(...pos);
    rect.times(resolution).setWidgetPos(label);
    label.addEventListener(
        gui.WidgetEventTypes.MouseButtonDblClick,
        (evt) => bridge.send("removeLine", { id })
    );
    pdfContainerLayout.addWidget(label);

    // Should not happen in production; the box should already have been removed
    if (lineBoxes[id]) {
        console.log(`Adding line box ${id} that already exists`);
        removeLineBox(id);
    }
    lineBoxes[id] = label;
}

/*
 * Given a split line and the position of the last added box, looks for the
 * subsequent box. If found, attempts to add it to the line.
 */
function findNextSplitBox(line, page, pos) {
    if (page != currentPage()) { return; } // Avoid synchronization issue
    const rect = new Rectangle(...pos).times(resolution);
    const nextPoint = rect.nextSplitStartPoint();
    //if (!boxcalc.sameColor(rect.center(), nextPoint)) { return; }

    const newRect = boxcalc.computeBoxAtPoint(nextPoint);
    if (newRect && Math.abs(newRect.max.y - rect.max.y) < 10) {
        // Have to manually provide the toolbar info because theoretically
        // the toolbar could have changed by this point
        addLineBox(newRect, { line, split: true });
    }
}

function removeLineBox(id) {
    const label = lineBoxes[id];
    if (label) {
        pdfContainerLayout.removeWidget(label);
        label.hide();
        delete lineBoxes[id];
    }
}

function execute(command, payload) {
    try {
        switch (command) {
            case "loadPdf":
                loadPdf(payload.form, payload.file, payload.lines);
            case "drawLineBox":
                drawLineBox(payload.id, payload.page, payload.pos);
                break;
            case "findNextSplitBox":
                findNextSplitBox(payload.line, payload.page, payload.pos);
                break;
            case "removeLineBox":
                removeLineBox(payload.id);
                break;
            case "setToolbarInfo":
                setToolbarInfo(payload);
                break;
            default:
                console.log("Unknown command");
        }
    } catch (e) { console.log(e); }
}
bridge.setHandler(execute);

/*
 * Show the window
 */

win.show();
global.win = win;

