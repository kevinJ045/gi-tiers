const {
	Jimp,
	intToRGBA
} = require('jimp');

Jimp.read('https://img.game8.co/3971304/b31ea373f82b660cb6f99abebb100e1b.png/show')
  .then((image) => {
    const width = image.bitmap.width;
    const height = image.bitmap.height;

    const leftWidth = Math.floor(width * 0.1);  // 10% from left
    const rightStart = Math.floor(width * 0.9); // 90% from left (start of right 10%)

    const colorCount = new Map();

    function processArea(startX, endX) {
      for (let x = startX; x < endX; x++) {
        for (let y = 0; y < height; y++) {
          const color = image.getPixelColor(x, y);
          const { r, g, b } = intToRGBA(color);

          // Ignore black and near-black colors
          if (r <= 10 && g <= 10 && b <= 10) continue;

          colorCount.set(color, (colorCount.get(color) || 0) + 1);
        }
      }
    }

    // Process left and right 10% of the image
    processArea(0, leftWidth);
    processArea(rightStart, width);

    // Find the most repeated non-black color
    let mostRepeatedColor = null;
    let maxCount = 0;

    for (const [color, count] of colorCount.entries()) {
      if (count > maxCount) {
        mostRepeatedColor = color;
        maxCount = count;
      }
    }

    if (!mostRepeatedColor) {
      console.log("No dominant color found (except black).");
      return;
    }

    const { r, g, b } = intToRGBA(mostRepeatedColor);

    // Print "COLOR" in the dominant background color
    console.log(`\x1b[1m\x1b[38;2;${r};${g};${b}mCOLOR\x1b[0m`);
  })
  .catch(err => console.error(err));
