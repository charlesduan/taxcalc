const gui = require("@nodegui/nodegui");

var handlers;


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
}

#toolBar QLabel {
    padding: 6px;
}
`);


/* Toolbar */

const toolBar = new gui.QWidget();
toolBar.setObjectName("toolBar");
rootView.layout.addWidget(toolBar);
toolBar.setLayout(new gui.FlexLayout());

var w = new gui.QLabel();
w.setText("File Name");
toolBar.layout.addWidget(w);

const pageBox = new gui.QComboBox();
toolBar.layout.addWidget(pageBox);

pageBox.addEventListener('currentIndexChanged', index => {
    // TODO: Should invalidate the current image
    makeContainer();
    handlers.selectPage(index + 1);
});



w = new gui.QLabel();
w.setText("Form Name");
toolBar.layout.addWidget(w);

const lineBox = new gui.QComboBox();
lineBox.addItem(undefined, "Line 1");
lineBox.addItem(undefined, "Line 2");
lineBox.addItem(undefined, "Line 3");
toolBar.layout.addWidget(lineBox);



/* Main PDF display */

const scrollArea = new gui.QScrollArea(win);
scrollArea.setObjectName("scrollArea");

rootView.layout.addWidget(scrollArea);

var pdfContainer;

function makeContainer() {
    pdfContainer = new gui.QWidget();

    pdfContainer.setLayout(new gui.FlexLayout(0));
    pdfContainer.setObjectName("container");
    pdfContainer.addEventListener(
        gui.WidgetEventTypes.MouseButtonPress,
        (evt) => processMouseClick("button press", evt)
    );
    pdfContainer.addEventListener(
        gui.WidgetEventTypes.MouseButtonRelease,
        (evt) => processMouseClick("button release", evt)
    );
    pdfContainer.addEventListener(
        gui.WidgetEventTypes.MouseButtonDblClick,
        (evt) => {
            processMouseClick("double click", evt);
            const mouseEvt = new gui.QMouseEvent(evt);
            const x = mouseEvt.x(), y = mouseEvt.y();
            handlers.computeBoxAtPoint(lineBox.currentText(), x, y);
        }
    );

    scrollArea.setWidget(pdfContainer);
}


/*
 * Functions
 */

function setNumPages(num) {
    pageBox.clear();
    for (var i = 1; i <= num; i++) {
        pageBox.addItem(undefined, "Page " + i.toString());
    }
}

function setPdfPage(buffer) {
    const image = new gui.QPixmap();
    const pdfDisplay = new gui.QLabel();
    image.loadFromData(buffer, "PNG");
    pdfDisplay.setPixmap(image);
    pdfContainer.layout.addWidget(pdfDisplay);
    pdfContainer.resize(image.width() + 50, image.height() + 50);


}

function addLineBox(text, xmin, ymin, xmax, ymax) {
    console.log("HERE");
    const label = new gui.QPushButton(pdfContainer);
    label.setText(text);
    label.setProperty("line", true);
    label.setInlineStyle(
        "left: " + xmin + "px; " +
        "top: " + ymin + "px; " +
        "min-width: " + (xmax - xmin) + "px; " +
        "max-width: " + (xmax - xmin) + "px; " +
        "min-height: " + (ymax - ymin) + "px; " +
        "max-height: " + (ymax - ymin) + "px; "
    );
    label.addEventListener(
        gui.WidgetEventTypes.MouseButtonDblClick,
        (evt) => {
            receiveLabelClick(label, text);
        },
    )
    pdfContainer.layout.addWidget(label);
}

function setEventHandlers(obj) {
    handlers = obj;
}

function processMouseClick(type, evt) {
    const mouseEvt = new gui.QMouseEvent(evt);
    console.log(type + " (" + mouseEvt.x() + ", " + mouseEvt.y() + ")");
}

function receiveLabelClick(label, text) {
    pdfContainer.layout.removeWidget(label);
    handlers.removeLineBox(text);
    label.hide();
}


/*
 * Export modules
 */

module.exports = {
    setNumPages,
    setPdfPage,
    setEventHandlers,
    addLineBox,
}

/*
 * Show the window
 */

win.show();
global.win = win;

