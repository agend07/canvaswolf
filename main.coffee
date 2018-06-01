sizeX = 45
canvasWidth = 0
canvasHeight = 0
ctx = null

data = null
buf8 = null
imageData = null
initialFrame = true

world =
    ceiling: '''
        111111111111111111111111111111111111111111111
        122223223232232111111111111111222232232322321
        122222221111232111111111111111222222211112321
        122221221232323232323232323232222212212323231
        122222221111232111111111111111222222211112321
        122223223232232111111111111111222232232322321
        111111111111111111111111111111111111111111111
        '''.replace(/\s/g,'')

    walling: '''
        111111111111111111111111111111111111111111111
        100000000000000111111111111111000000000000001
        103330001111000111111111111111033300011110001
        103000000000000000000000000000030000030000001
        103330001111000111111111111111033300011110001
        100000000000000111111111111111000000000000001
        111111111111111111111111111111111111111111111
        '''.replace(/\s/g,'')


    floring: '''
        111111111111111111111111111111111111111111111
        122223223232232111111111111111222232232322321
        122222221111232111111111111111222222211112321
        122222221232323323232323232323222222212323231
        122222221111232111111111111111222222211112321
        122223223232232111111111111111222232232322321
        111111111111111111111111111111111111111111111
        '''.replace(/\s/g,'')

fpsSpan = document.getElementById("fps")

keys = {}
window.onkeyup = (e) -> keys[e.keyCode] = false
window.onkeydown = (e) -> keys[e.keyCode] = true

pcast = (size, res, y) -> size / (2*y - res)
dec = (n) -> n % 1
round3 = (n) -> Math.round(n * 1000) / 1000

window.refresh = () ->
    console.log 'here'
    initialFrame = true

settings = document.getElementById('settings')
settings.addEventListener('change', () -> initialFrame=true)

class Point
    constructor: (@x=0, @y=0) ->
    toString: -> "(#{@x}, #{@y})"
    rag: -> new Point(-@y, @x)
    add: (other) -> new Point(@x+other.x, @y+other.y)
    sub: (other) -> new Point(@x-other.x, @y-other.y)
    mul: (n) -> new Point(@x*n, @y*n)
    div: (n) -> new Point(@x/n, @y/n)
    mag: -> Math.sqrt(@x*@x + @y*@y)
    unt: -> @div(@mag())
    slope: -> @y/@x
    turn: (t) ->
        sinT = Math.sin(t)
        cosT = Math.cos(t)
        new Point(@x*cosT - @y*sinT, @x*sinT + @y*cosT)
    sh: (b) ->
        x = if b.x > 0 then Math.floor(@x+1) else Math.ceil(@x-1)
        y = b.slope() * (x-@x) + @y
        new Point(x, y)
    sv: (b) ->
        y = if b.y > 0 then Math.floor(@y+1) else Math.ceil(@y-1)
        x = (y-@y) / b.slope() + @x
        new Point(x, y)
    tile: (tiles) -> tiles[Math.floor(@x) + Math.floor(@y)*sizeX] - '0'
    cmp: (b, c) -> if b.sub(@).mag() < c.sub(@).mag() then b else c

class Line
    constructor: (@a=new Point(), @b=new Point()) ->
    rotate: (t) -> new Line(@a.turn(t), @b.turn(t))
    lerp: (n) -> @b.sub(@a).mul(n).add(@a)

class Hit
    constructor: (@tile=0, @where=new Point()) ->

class Wall
    constructor: (@top, @bot, @size) ->


project = (res, fov, corrected) ->
    size = 0.5 * fov.a.x * res / corrected.x
    top = (res-size)/2
    bot = (res+size)/2
    new Wall(
        if top < 0 then 0 else Math.floor(top),
        if bot > res then Math.floor(res) else Math.floor(bot),
        size)

cast = (where, direction, walling) ->
    ray = where.cmp(where.sh(direction), where.sv(direction))

    delta = direction.mul(0.01) # point
    dx = new Point(delta.x, 0)
    dy = new Point(0, delta.y)

    tmp = delta
    if dec(ray.x) == 0 then tmp = dx
    else if dec(ray.y) == 0 then tmp = dy
    test = ray.add(tmp)


    hit = new Hit(test.tile(walling), ray)
    if hit.tile then hit else cast(ray, direction, walling)

class Hero
    constructor: (@fov=new Line(), @where=new Point(), @velocity=new Point(), @speed=0, @acceleration=0, @theta=0) ->
    spin: () ->
        if keys[37] then @theta -= 0.1 # LEFT
        if keys[39] then @theta += 0.1 # RIGHT
        return @
    move: () ->
        last = hero.where

        if keys[38] or keys[40] or keys[88] or keys[90]
            reference = new Point(1, 0)
            direction = reference.turn(hero.theta)
            acceleration = direction.mul(hero.acceleration)

            if keys[38] then hero.velocity = hero.velocity.add(acceleration)        # UP
            if keys[40] then hero.velocity = hero.velocity.sub(acceleration)        # DOWN
            if keys[88] then hero.velocity = hero.velocity.add(acceleration.rag())  # X
            if keys[90] then hero.velocity = hero.velocity.sub(acceleration.rag())  # Z

        else hero.velocity = hero.velocity.mul(1 - hero.acceleration/hero.speed)

        if hero.velocity.mag() > hero.speed then hero.velocity = hero.velocity.unt().mul(hero.speed)

        if hero.velocity.mag() < 0.005 then hero.velocity = new Point(0, 0)

        hero.where = hero.where.add(hero.velocity)

        if hero.where.tile(world.walling)
            hero.velocity = new Point(0, 0)
            hero.where = last
        return @

hero = new Hero(
    new Line(new Point(1, -1), new Point(1, 1)),    # fov
    new Point(3.5, 3.5),                            # where
    new Point(0, 0),                                # velocity
    0.1,                                            # speed
    0.01,                                           # acceleration
    0)                                              # theta


fps = 0
setInterval (-> fpsSpan.innerHTML = round3(fps)), 200

getDecimal = (point) ->
    decX = dec(point.x)
    if decX > 0 then return decX
    return dec(point.y)

render = (start) ->
    lastWhere = hero.where
    lastTheta = hero.theta

    hero.spin()
    hero.move()

    if lastTheta != hero.theta or lastWhere.x != hero.where.x or lastWhere.y != hero.where.y or initialFrame
        initialFrame = false

        camera = hero.fov.rotate(hero.theta)
        clear()

        for x in [0...canvasWidth]

            column = camera.lerp(x/canvasWidth)
            hit = cast(hero.where, column, world.walling)
            uCord = getDecimal(hit.where)

            ray = hit.where.sub(hero.where)
            corrected = ray.turn(-hero.theta)

            if document.getElementById("fisheye").checked
                corrected = corrected.add(new Point(1, 0))

            wall = project(canvasWidth, hero.fov, corrected)
            trace = new Line(hero.where, hit.where)

            # ceiling
            if document.getElementById("ceiling").checked
                for y in [0...wall.top]
                    tile = trace.lerp(-pcast(wall.size, canvasWidth, y+0)).tile(world.ceiling)
                    draw(x, y, tile)

            height = wall.bot - wall.top

            # wall
            for y in [wall.top...wall.bot]
                vCord = (wall.bot-y)/height
                draw(x, y, hit.tile)

                sel = document.getElementById('wall')

                switch document.getElementById('wall').selectedIndex
                    when 0 then draw(x, y, hit.tile)
                    when 1 then drawGradient(x, y, hit.Tile, uCord, vCord)
                    when 2 then drawTexture(x, y, hit.Tile, uCord, vCord)

            # flooring
            if document.getElementById("floor").checked
                for y in [wall.bot...canvasWidth]
                    tile = trace.lerp(pcast(wall.size, canvasWidth, y+1)).tile(world.floring)
                    draw(x, y, tile)


        imageData.data.set(buf8)
        ctx.putImageData(imageData, 0, 0)


    stop = performance.now()
    ms = stop - start
    if ms < 1 then ms = 1
    fps = 1000/(ms)

    requestAnimationFrame(render)

textureCanvas = null
textureCanvasWidth = null
textureCanvasHeight = null
textureData = null

loadTexture = () ->
    img = document.getElementById('texture')
    textureCanvas = document.createElement('canvas')
    textureCanvas.width = textureCanvasWidth = img.width
    textureCanvas.height = textureCanvasHeight = img.height
    tCtx = textureCanvas.getContext('2d')
    tCtx.drawImage(img, 0, 0, img.width, img.height)

    tmp = tCtx.getImageData(0, 0, textureCanvasWidth, textureCanvasWidth)
    textureData = Uint32Array.from(tmp.data)
    window.cos = textureData

draw = (x, y, tile) ->
    idx = (y * canvasWidth + x)
    switch tile
        when 1 then data[idx] = 0xFF4A0000
        when 2 then data[idx] = 0xFF003A00
        when 3 then data[idx] = 0xFF00002a

drawTexture = (x, y, tile, uCord, vCord) ->
    [r, g, b, a] = getTextureColor(uCord, vCord)
    color = 0xFF000000
    color = color | (b << 16)
    color = color | (g << 8)
    color = color | (r)

    idx = (y * canvasWidth + x)
    data[idx] = color

getTextureColor = (u, v) ->
    x = Math.trunc(u*textureCanvasWidth)
    y = Math.trunc((1-v)*textureCanvasHeight)
    idx = (y * textureCanvasWidth + x) * 4
    raw = textureData.slice(idx, idx+4)
    return raw

drawGradient = (x, y, tile, uCord, vCord) ->
    red = (1 - uCord + vCord) * 128
    green = (uCord + vCord) * 128
    blue = 128

    color = 0xFF000000
    color = color | red
    color = color | (green << 8)

    idx = (y * canvasWidth + x)
    data[idx] = color

clear = () ->
    for idx in [0...canvasHeight*canvasWidth]
        data[idx] = 0xFFAAFFAA

run = ->
    canvas = document.getElementById('canvas')
    canvasWidth = canvas.width
    canvasHeight = canvas.height
    ctx = canvas.getContext('2d')

    imageData = ctx.getImageData(0, 0, canvasWidth, canvasHeight)
    buf = new ArrayBuffer(imageData.data.length)
    buf8 = new Uint8ClampedArray(buf)
    data = new Uint32Array(buf)

    loadTexture()

    requestAnimationFrame(render)
run()

