const formgui = require("./formgui");
const bridge = require("./apibridge")

formgui.loadPdf("f1040.pdf", '1040', [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10'
]);

bridge.setfd(parseInt(process.argv[2]), parseInt(process.argv[3]));
