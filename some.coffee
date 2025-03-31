import '#std'
import * as cheerio from "cheerio"
import { Jimp, intToRGBA } from "jimp"

using namespace std::ns ->
  define Main class TierList
    @url = "https://game8.co/games/Genshin-Impact/archives/297465"
    @cacheDir = './_history'
    
    # Ensure cache directory exists
    @ensureCache: -> mkdir @cacheDir, recursive: true

    @colorizeName: (text, { r, g, b } = {}) -> "\x1b[1m\x1b[38;2;#{r};#{g};#{b}m#{text}\x1b[0m"

    # Extract dominant color and determine element
    @getElementFromImage: (imageURL) ->
      return wait new Promise (resolve, reject) ->
        Jimp.read(imageURL)
          .then (image) ->
            width = image.bitmap.width
            height = image.bitmap.height

            x = Math.floor(width * 0.1)
            y = Math.floor(height / 2)

            resolve intToRGBA(image.getPixelColor(x, y))
          .catch reject

    # Fetch and parse data if JSON is missing
    @fetchAndParse: (url, jsonFile) ->
      pageData = wait curl url: url, text: true
      dom = cheerio.load(pageData)
      target = dom('h2').filter((e, el) => dom(el).text().match(/^Genshin Impact Tier List for Version \d+\.\d+$/)).first()
      element = target.next()

      jsonData = { version: "unknown", tabs: [] }

      # Parse tier list tabs
      element.find('.a-tab').each (i, tab) ->
        tabName = dom(tab).text().trim()
        jsonData.tabs.push { name: tabName, tiers: [] }

      # Parse tables inside tabs
      element.find('.a-tabPanels .a-tabPanel').each (i, panel) ->
        rows = dom(panel).find('table tbody tr')
        currentTier = null

        rows.each (j, row) =>
          cells = dom(row).find('th, td')
          if cells.length == 4
            currentTier = dom(cells[0]).text().trim()
            jsonData.tabs[i].tiers.push { tier: currentTier, MainDPS: [], SubDPS: [], Support: [] }
          else if currentTier
            jsonData.tabs[i].tiers.last()[Object.keys(jsonData.tabs[i].tiers.last())[j]] = cells.find('a img').map((k, img) ->
              { name: dom(img).attr('alt'), image: dom(img).attr('src'), color: @getElementFromImage(dom(img).attr('src')), element: null }
            ).get()

      # Save JSON
      write jsonFile, JSON.stringify(jsonData, null, 2)
      return jsonData

    # Load JSON (cached or fresh)
    @loadJSON: (jsonFile) ->
      if exists jsonFile
        print "Using cached data: #{jsonFile}"
        return JSON.parse read jsonFile
      else
        print "Fetching new data..."
        return wait @fetchAndParse(@url, jsonFile)

    # Display tier lists
    @displayTierLists: (jsonData) ->
      print "Tier lists:"
      jsonData.tabs.forEach (tab, i) -> print "#{i + 1}, #{tab.name}"

      num = int input "Choose tier list (1-#{jsonData.tabs.length}): "
      if num < 1 or num > jsonData.tabs.length
        print "Invalid choice."
        return

      chosenTab = jsonData.tabs[num - 1]

      print "\n#{chosenTab.name}\n" + "-".repeat(20)

      for tierEntry in chosenTab.tiers
        print "[#{tierEntry.tier}]"

        for role, characters of tierEntry
          if role is "tier" then continue

          characterNames = characters.map (character) =>
            if not character.color
              character.color = @getElementFromImage(character.image)
		
            @colorizeName character.name, character.color

          print "  #{role}: " + characterNames.join(', ')

        print ""

    # Main function
    @main: (argv) ->
      @ensureCache()
      jsonFile = "#{@cacheDir}/" + basename(@url) + ".json"
      jsonData = @loadJSON(jsonFile)
      @displayTierLists(jsonData)
