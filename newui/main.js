const formgui = require("./formgui");
const bridge = require("./apibridge")

bridge.setfd(parseInt(process.argv[2]), parseInt(process.argv[3]));
