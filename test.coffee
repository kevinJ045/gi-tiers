c = (imageURL) ->
  return wait new Promise (resolve, reject) ->
    image = await Jimp.read(imageURL)
      width = image.bitmap.width
      height = image.bitmap.height
      total = width * height
      r = g = b = 0

      # Sample pixels for average color
      for x in [0...width] by 10
        for y in [0...height] by 10
          {r: pr, g: pg, b: pb} = Jimp.intToRGBA(image.getPixelColor(x, y))
          r += pr
          g += pg
          b += pb

      r = r / total
      g = g / total
      b = b / total

      print r, g, b

      # element =
      #   if r > 150 and g < 100 and b < 100 then "Pyro"
      #   else if b > 150 and g > 150 then "Cryo"
      #   else if b > 150 then "Hydro"
      #   else if g > 150 and b < 100 then "Dendro"
      #   else if g > 100 and b > 100 then "Anemo"
      #   else if r > 150 and g > 150 then "Geo"
      #   else if r > 100 and b > 100 then "Electro"
      #   else "Unknown"
