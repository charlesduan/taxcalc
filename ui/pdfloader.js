const Canvas = require("canvas");
const fs = require("fs");
const fsPromises = require("fs/promises");
const pdfjs = require("pdfjs-dist/legacy/build/pdf.mjs");
const cp = require("node:child_process");
const readline = require("node:readline/promises");
const buffer = require('node:buffer');
const { Poppler } = require("node-poppler");

const poppler = new Poppler();

let pdfFile = undefined;
let pdfDoc = undefined;
let pdfPageCount = undefined;
let theCanvas = undefined;

async function loadPdf(filename) {
    console.log("Received command for file " + filename);

    pdfFile = filename;
    const res = await poppler.pdfInfo(filename, { printAsJson: true });
    pdfPageCount = parseInt(res.pages);
    console.log(`Result is <${pdfPageCount}>`);

    const file = await fsPromises.readFile(filename);
    console.log("Read file");
    const data = new Uint8Array(file);
    pdfDoc = await pdfjs.getDocument({
        data,
        cMapUrl: "node_modules/pdfjs-dist/cmaps/",
        cMapPacked: true,
        useSystemFonts: true,
        disableFontFace: false,
        standardFontDataUrl: "node_modules/pdfjs-dist/standard_fonts/",
        pdfBug: true,
    }).promise;
    console.log("Loaded document");
}

function numPages() {
    return pdfPageCount;
}

async function selectPage(page, resolution) {
    if (pdfDoc === undefined) { return; }
    console.log("Loading page " + page);

    const imagebytes = await poppler.pdfToCairo(pdfFile, undefined, {
        singleFile: true,
        firstPageToConvert: page,
        lastPageToConvert: page,
        pngFile: true,
        resolutionXYAxis: resolution,
    });

    console.log(`imagebytes is ${imagebytes}`);
    const image = new Canvas.Image();
    image.src = imagebytes;

    const pageData = await pdfDoc.getPage(page);
    console.log("Loaded page " + page);
    const viewport = pageData.getViewport({ scale: resolution });
    theCanvas = Canvas.createCanvas(viewport.width, viewport.height);

    await pageData.render({
        canvasContext: theCanvas.getContext("2d"),
        viewport,
    }).promise
    console.log("Done rendering");
    return theCanvas;
}

module.exports = {
    loadPdf,
    selectPage,
    numPages,
}
