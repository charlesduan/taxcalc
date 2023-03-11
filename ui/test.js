let { QLabel, FlexLayout, QWidget, QMainWindow } = require("@nodegui/nodegui");

// Create a root view and assign a flex layout to it.
const rootView = new QWidget();
const rootLayout = new FlexLayout();
rootView.setLayout(rootLayout);
rootLayout.setFlexNode(rootView.getFlexNode());
rootView.setObjectName("rootView");

// Create two widgets - one label and one view
const label = new QLabel();
label.setText("Hello");
label.setObjectName("label");

const view = new QWidget();
view.setObjectName("view");

// Now tell rootView layout that the label and the other view are its children
rootLayout.addWidget(label);
rootLayout.addWidget(view);

// Tell FlexLayout how you want children of rootView to be poisitioned
rootView.setStyleSheet(`
  #rootView{
    flex: 1;
    background-color: blue;
  }
  #label {
   flex: 1;
   color: white;
   background-color: green;
  }
  #view {
    flex: 3;
    background-color: white;
  }
`);

const win = new QMainWindow();
win.setCentralWidget(rootView);
win.show();
global.win = win;
