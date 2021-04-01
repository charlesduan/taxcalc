const gui = require("@nodegui/nodegui");

var handlers;


const win = new gui.QMainWindow();
win.resize(612 * 2 + 20, 792 * 2);

const rootView = new gui.QWidget();
rootView.setLayout(new gui.FlexLayout());
rootView.setObjectName("rootView");

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
    if (pdfDisplay.pixmap() !== undefined) {
        // TODO: Should invalidate the current image
        handlers.selectPage(index + 1);
    }
});


w = new gui.QLabel();
w.setText("Form Name");
toolBar.layout.addWidget(w);

const lineBox = new gui.QComboBox();
lineBox.addItem(undefined, "Line 1");
lineBox.addItem(undefined, "Line 2");
lineBox.addItem(undefined, "Line 3");
toolBar.layout.addWidget(lineBox);

const scrollArea = new gui.QScrollArea(win);
scrollArea.setObjectName("scrollArea");

rootView.layout.addWidget(scrollArea);

const pdfDisplay = new gui.QLabel();
pdfDisplay.addEventListener(
    gui.WidgetEventTypes.MouseButtonPress,
    (evt) => processMouseClick("button press", evt)
);
pdfDisplay.addEventListener(
    gui.WidgetEventTypes.MouseButtonRelease,
    (evt) => processMouseClick("button release", evt)
);
pdfDisplay.addEventListener(
    gui.WidgetEventTypes.MouseButtonDblClick,
    (evt) => processMouseClick("double click", evt)
);
pdfDisplay.setLayout(new gui.QBoxLayout(0));

scrollArea.setWidget(pdfDisplay);




rootView.setStyleSheet(`
#scrollArea {
    flex: 1;
}
#toolBar {
    height: 60px;
    flex-direction: row;
}

#toolBar QLabel {
    padding: 6px;
}
`);

win.setCentralWidget(rootView);

win.show();
global.win = win;

function setNumPages(num) {
    pageBox.clear();
    for (var i = 1; i <= num; i++) {
        pageBox.addItem(undefined, "Page " + i.toString());
    }
    handlers.selectPage(1);
}

function setPdfPage(buffer) {
    const image = new gui.QPixmap();
    image.loadFromData(buffer, "PNG");
    pdfDisplay.setPixmap(image);
    pdfDisplay.resize(image.width(), image.height());
    pdfDisplay.repaint();


}

function setEventHandlers(obj) {
    handlers = obj;
}

module.exports = {
    setNumPages,
    setPdfPage,
    setEventHandlers,
}

function processMouseClick(type, evt) {
    const mouseEvt = new gui.QMouseEvent(evt);
    console.log(type + " (" + mouseEvt.x() + ", " + mouseEvt.y() + ")");
}

