import '#std'
import * as cheerio from "cheerio"
import { Jimp, intToRGBA } from "jimp"
import conf from "conf"
import * as loading from "loading-cli"

using namespace std::ns ->
  define Main class TierList
    @cacheDir = './_history'
    @settings = conf.optionCenter 'config', {
   		url: "https://game8.co/games/Genshin-Impact/archives/297465"
   	}
    
    @ensureCache: -> mkdir @cacheDir, recursive: true

    @colorizeName: (text, { r, g, b } = {}) -> "\x1b[1m\x1b[38;2;#{r};#{g};#{b}m#{text}\x1b[0m"

    @getElementFromImage: (imageURL) ->
      return wait new Promise (resolve, reject) ->
        Jimp.read(imageURL)
          .then (image) ->
            width = image.bitmap.width
            height = image.bitmap.height
    
            leftWidth = Math.floor(width * 0.05)
            rightStart = Math.floor(width * 0.95)
    
            colorCount = new Map()
    
            processArea = (startX, endX) ->
              for x in [startX...endX]
                for y in [0...height]
                  color = image.getPixelColor(x, y)
                  { r, g, b } = intToRGBA(color)
    
                  continue if r <= 10 and g <= 10 and b <= 10
    
                  colorCount.set color, (colorCount.get(color) or 0) + 1
    
            processArea 0, leftWidth
            processArea rightStart, width
    
            mostRepeatedColor = null
            maxCount = 0
            
            for [color, count] in [...colorCount.entries()]
              # print color, count
              if count > maxCount
                mostRepeatedColor = color
                maxCount = count
    
            unless mostRepeatedColor
              return resolve { r: 255, g: 255, b: 255 }
    
            { r, g, b } = intToRGBA mostRepeatedColor
            resolve { r, g, b }
          .catch reject

    @fetchAndParse: (url, jsonFile) ->
      @loading.text = 'Fetching Page'
      pageData = wait curl url: url, text: true
      dom = cheerio.load(pageData)
      target = dom('h2').filter((e, el) => dom(el).text().match(/^Genshin Impact Tier List for Version \d+\.\d+$/)).first()
      tabContainer = target.next()

      jsonData = { version: target.text().split(' ').pop(), tabs: [] }
      @loading.text = 'Constructing Data'

      tabs = tabContainer.find('.a-tabs .a-tab')
      @loading.text = 'Caching all character info...'
      tabs.each (i, tab) =>
        tabName = dom(tab).text().trim()
        
        tabData =
          name: tabName
          tiers: []

        tabPanel = tabContainer.find('.a-tabPanels .a-tabPanel').eq(i)

        rows = tabPanel.find('table tbody tr')
        tierName = ""

        rows.each (j, row) =>
          cells = dom(row).find('th, td')

          if cells.length is 4
            tierName = dom(cells[0]).find('img').attr('alt') or ""

            tierData =
              tier: tierName
              "Main DPS": []
              "Sub-DPS": []
              "Support": []

            ["Main DPS", "Sub-DPS", "Support"].forEach (role, index) =>
              dom(cells[index + 1]).find('a').each (k, link) =>
                character =
                  name: dom(link).find('img').attr('alt')?.replace("Genshin - ", "").replace(RegExp("(DPS|Sub-DPS|Support) Rank"), "").trim()
                  image: dom(link).find('img').attr('data-src')
                  link: dom(link).attr('href')
                  color: @getElementFromImage(dom(link).find('img').attr('data-src'))

                tierData[role].push(character)
    
            if tierName then tabData.tiers.push(tierData)

        jsonData.tabs.push(tabData)

      @loading.text = 'Saving data...'
      write jsonFile, JSON.stringify(jsonData, null, 2)
      return jsonData

    @loadJSON: (jsonFile) ->
      if exists jsonFile
        return JSON.parse read jsonFile
      else
        @loading = loading("Staring").start()
        json = @fetchAndParse(@settings.get('url'), jsonFile)
        @loading.stop()
        return json

    @displayTierLists: (jsonData) ->
      print "Genshin Impact Version #{jsonData.version} Character Tier lists:"
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

    @main: (argv) ->
      try
        @ensureCache()
        jsonFile = "#{@cacheDir}/" + basename(@settings.get('url')) + ".json"
        jsonData = @loadJSON(jsonFile)
        @displayTierLists(jsonData)
      catch(e)
        print "Error Occured"
        print "If the errors persist, try resetting the url using rew conf, the conf key is url"
