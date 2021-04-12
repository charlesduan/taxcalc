const fs = require('fs');
const readline = require('readline');

async function readFile(filename) {
    const fileStream = 
    const rl = readline.createInterface({
        input: fs.createReadStream(filename),
        crlfDelay: Infinity,
    });

    for await (const line of rl) {
    }
}

/*
 * Produces a union of the left and right arrays, preserving the order of
 * elements in both arrays as closely as possible. The order of the left array
 * will be preferred over that of the right array.
 */
function merge_arrays(left, right) {

    // Copy the left array into a new array.
    let result = left.slice()

    // Set a cursor insertPos on the result array. It will point to the item
    // after which new items will be added; it starts at -1 to indicate that any
    // new items should be added at the beginning.
    let insertPos = -1;

    // Iterate through each item in the right array.
    for (let rightElt of right) {

        // Find where that item is in the result array.
        let pos = result.indexOf(rightElt);

        // If the item was found, then move the insertPos cursor to that
        // position, so future items from the right array are inserted after
        // this one. If the item was not found, then insert it after the cursor
        // and advance the cursor to the newly added item.
        if (pos >= 0) {
            insertPos = pos;
        } else {
            insertPos++;
            result.splice(insertPos, 0, rightElt);
        }
    }
    return result;
}
