const Canvas = require("canvas");
const fs = require("fs");
const pdfjs = require("pdfjs-dist/es5/build/pdf.js");

const formgui = require("./formgui.js");




const data = new Uint8Array(fs.readFileSync("f1040.pdf"));

const loadingTask = pdfjs.getDocument({
    data,
    cMapUrl: "node_modules/pdfjs-dist/cmaps/",
    cMapPacked: true
});

var theCanvas;

var thePdfDoc;


loadingTask.promise.then(pdfDoc => {
    console.log("Loaded document.");
    thePdfDoc = pdfDoc;
    formgui.setNumPages(pdfDoc.numPages);
})

async function selectPage(page) {
    console.log("Loading page " + page);
    const pageData = await thePdfDoc.getPage(page);
    console.log("Loaded page " + page);
    const viewport = pageData.getViewport({ scale: 2 });
    theCanvas = Canvas.createCanvas(viewport.width, viewport.height);

    await pageData.render({
        canvasContext: theCanvas.getContext("2d"),
        viewport,
    }).promise
    console.log("Done rendering");
    formgui.setPdfPage(theCanvas.toBuffer());
}

formgui.setEventHandlers({
    selectPage,
});


