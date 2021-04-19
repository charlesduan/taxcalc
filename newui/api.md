# API for Node/Ruby Communication


## Data structure for line positions

Form
* Has many lines

Line: Regular
* Page number
* x, y, width, height

Line: Array
* Just like regular line but with different numbers separated with #

Line: Boxed
* Split pattern
* Multiple regular lines
* Line numbers separated with square brackets
* UI doesn't need to know what's a "boxed" line; just passes line numbers

## Commands from Ruby to Node

Load initial metadata
* Returns:
  * List of forms
  * Which forms are complete

Load PDF file
* PDF name
* Form name

Load page
* Page number

Remove box
* ID of box

Draw box
* ID of box
* Coordinates (absolute in points) of box

Set toolbar


## Commands from Node to Ruby

Add box
* Line number
* Position

Remove box
* Line number
* For boxed lines, index of box removed
  * Must remove all boxes >= index
  * But Ruby will do that and invoke "remove box" so UI doesn't remove them yet

Save

Switch form
* A PDF file for the form
