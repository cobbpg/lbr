package {

  import flash.display.*;
  import flash.events.*;
  import flash.geom.*;
  import flash.utils.*;

  public class LBR extends Sprite {

    [Embed(source="/usr/share/fonts/truetype/ttf-larabie-straight/zekton__.ttf", fontName="Zekton",
	   embedAsCFF="false", unicodeRange="U+0030-U+0039,U+0041-U+005A,U+0061-U+007A")]
    public static const FONT_ZEKTON:Class;

    public var game:Game = null;
    public var menu:Menu = null;

    public function LBR():void {
      initMenu();

      stage.frameRate = 1 / tstep;
      stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
      stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
      stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
    }

    public function cleanup():void {
      while (numChildren > 0) {
	removeChildAt(0);
      }

      game = null;
      menu = null;
    }

    public function initMenu():void {
      cleanup();
      menu = new Menu([{text:"Play", action:initGame}, {text:"Help", action:null}]);
      addChild(menu);
      menu.init();
    }

    public function initGame():void {
      cleanup();
      game = new Game(initMenu);
      addChild(game);
      game.init();
    }

    public function onEnterFrame(e:Event):void {
      if (game) game.onEnterFrame(e);
    }

    public function onKeyDown(e:KeyboardEvent):void {
      if (game) game.onKeyDown(e);
      if (menu) menu.onKeyDown(e);
    }

    public function onKeyUp(e:KeyboardEvent):void {
      if (game) game.onKeyUp(e);
    }

  }

}

import flash.display.*;
import flash.events.*;
import flash.geom.*;
import flash.text.*;
import flash.utils.*;

const tstep:Number = 0.02;
const starSize:Number = 40;

internal class Menu extends Sprite {

  public static const normalCol:int = 0xffffff;
  public static const activeCol:int = 0xff0000;

  public var items:Array;
  public var active:int = 1;

  public function Menu(menuItems:Array):void {
    items = menuItems;
  }

  public function init():void {
    graphics.beginFill(0x000000);
    graphics.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
    graphics.endFill();

    addText("LOVE Breaks Rocks", 70, 35);
    for (var i:int = 0; i < items.length; i++) {
      addText(items[i].text, 150 + i * 35, 25);
    }

    var tf:TextField = getChildAt(active) as TextField;
    tf.textColor = activeCol;
  }

  public function addText(text:String, pos:Number, size:Number):void {
    var tf:TextField = new TextField();
    tf.embedFonts = true;
    tf.width = stage.stageWidth;
    tf.autoSize = TextFieldAutoSize.CENTER;
    tf.defaultTextFormat = new TextFormat("Zekton", size, normalCol);
    tf.text = text;
    tf.y = pos;

    addChild(tf);
  }

  public function onKeyDown(e:KeyboardEvent):void {
    var tf:TextField = getChildAt(active) as TextField;
    tf.textColor = normalCol;

    switch (e.keyCode) {
    case 38: // up
    case 87: // W
      active--;
      if (active < 1) {
	active = numChildren - 1;
      }
      break;
    case 40: // down
    case 83: // S
      active++;
      if (active >= numChildren) {
	active = 1;
      }
      break;
    case 13: // enter
      if (items[active - 1].action) {
	items[active - 1].action();
      }
      break;
    }

    tf = getChildAt(active) as TextField;
    tf.textColor = activeCol;
  }

}

internal class Game extends Sprite {

  public var tprev:Number = getTimer();
  public var paused:Boolean = false;
  public var asteroids:Array = new Array();
  public var player:Player = new Player();
  public var star:Sunflare = new Sunflare();
  public var endGame:Function;

  public function Game(callback:Function):void {
    endGame = callback;
  }

  public function init():void {
    addChild(star);
    star.x = stage.stageWidth / 2;
    star.y = stage.stageHeight / 2;
    addChild(player);
    player.init();
    addAsteroid();

    var m:Matrix = new Matrix();
    var ss:Number = starSize * 2;
    m.createGradientBox(ss, ss, 0, (stage.stageWidth - ss) / 2, (stage.stageHeight - ss) / 2);
    graphics.beginGradientFill(GradientType.RADIAL, [0xffffff, 0xffcc00, 0xff0000, 0x330000, 0x000000],
			       [1, 1, 1, 1, 1], [0, 32, 160, 224, 255], m);
    graphics.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
    graphics.endFill();
  }

  public function onEnterFrame(e:Event):void {
    if (paused) return;

    var tcur:int = getTimer();
    var dt:Number = (tcur - tprev) * 0.001;
    tprev = tcur;

    player.update(dt);
    star.update(dt);

    var changed:Boolean = false;
    var added:Array = new Array();
    for each (var a:Asteroid in asteroids) {
      a.update(dt, player.energy);

      var dx:Number = player.x - a.x;
      var dy:Number = player.y - a.y;
      var d:Number = vecLen(dx, dy);

      if (d < a.size * Asteroid.unit + Player.size) {
	if (a.lethal) {
	  endGame();
	  return;
	}

	changed = true;

	var v:Number = -2 * (player.vx * dx + player.vy * dy) / (d * d * Asteroid.startSize) * a.size
	  player.vx += dx * v;
	player.vy += dy * v;

	if (a.size == Asteroid.startSize) {
	  added.push({size:-1, x:-1, y:-1});
	  added.push({size:-1, x:-1, y:-1});
	}

	if (a.size > 0) {
	  a.init(false);
	  a.size--;
	}

	if (a.size > 0) {
	  a.redraw();
	  added.push({size:a.size, x:a.x, y:a.y});
	  added.push({size:a.size, x:a.x, y:a.y});
	} else {
	  removeChild(a);
	}

      }
    }

    if (changed) {
      asteroids = asteroids.filter
	(function(e:Asteroid, i:int, a:Array):Boolean {
	  return e.size > 0;
	});
      for each (var na:* in added) {
	addAsteroid(na.size, na.x, na.y);
      }
    }
  }

  public function addAsteroid(size:int = -1, px:Number = -1, py:Number = -1):void {
    var a:Asteroid = new Asteroid(size == -1 ? Asteroid.startSize : size);

    addChild(a);
    a.init();
    if ((px >= 0) && (py >= 0)) {
      a.x = px;
      a.y = py;
    }
    asteroids.push(a);
  }

  public function onKeyDown(e:KeyboardEvent):void {
    handleKeyEvent(e.keyCode, true);
    if (e.keyCode == 80) { // P
      paused = !paused;
      transform.colorTransform = paused ? new ColorTransform(0.5, 0.5, 0.5) : new ColorTransform();
      tprev = getTimer();
    }
    if (e.keyCode == 27) { // escape
      endGame();
    }
  }

  public function onKeyUp(e:KeyboardEvent):void {
    handleKeyEvent(e.keyCode, false);
  }

  public function handleKeyEvent(code:uint, val:Boolean):void {
    switch (code) {
    case 38: // up
    case 87: // W
      player.throttle = val;
      break;
    case 37: // left
    case 65: // A
      player.turnLeft = val;
      break;
    case 39: // right
    case 68: // D
      player.turnRight = val;
      break;
    }
  }

}

internal class Asteroid extends Sprite {

  public static const unit:Number = 10;
  public static const startSize:Number = 3;

  public var size:int;
  public var vx:Number;
  public var vy:Number;
  public var lethal:Boolean = false;

  public function Asteroid(s:int) {
    size = s;
    redraw();
  }

  public function init(setPos:Boolean = true):void {
    var dir:Number = Math.random() * 2 * Math.PI;

    vx = Math.sin(dir) * (9 - size * 2) * unit;
    vy = Math.cos(dir) * (9 - size * 2) * unit;

    if (setPos) {
      x = Math.random() * stage.stageWidth;
      if (Math.random() < 0.5) {
	y = -(size + 1) * unit;
      } else {
	y = stage.stageHeight + (size + 1) * unit;
      }
    }
  }

  public function update(dt:Number, pnrg:Number):void {
    if (borderHit(x, vx, size * unit, stage.stageWidth)) {
      vx *= -1;
    }

    if (borderHit(y, vy, size * unit, stage.stageHeight)) {
      vy *= -1;
    }

    var dx:Number = x - stage.stageWidth / 2;
    var dy:Number = y - stage.stageHeight / 2;
    var d:Number = vecLen(dx, dy);
    if (d < starSize * 3) {
      vx += dx / d * dt * 30;
      vy += dy / d * dt * 30;
    }

    x += vx * dt;
    y += vy * dt;

    var l:Boolean = pnrg * startSize * 2 < size;
    if (l != lethal) {
      lethal = l;
      transform.colorTransform = lethal ? new ColorTransform(1, 0, 0) : new ColorTransform();
    }
  }

  public function redraw():void {
    graphics.clear();
    graphics.beginFill(0x999999);
    graphics.lineStyle(1, 0x555555);
    graphics.drawCircle(0, 0, size * unit);
    graphics.endFill();
  }

}

internal class Player extends Sprite {

  public static const acceleration:Number = 50;
  public static const turnSpeed:Number = 200;
  public static const depletionRate:Number = 0.2;
  public static const refillRate:Number = 1;
  public static const size:Number = 10;

  public var energy:Number = 1;

  public var vx:Number = 0;
  public var vy:Number = 0;

  public var throttle:Boolean = false;
  public var turnLeft:Boolean = false;
  public var turnRight:Boolean = false;

  public function Player():void {
    const c30:Number = Math.cos(Math.PI / 6);
    graphics.beginFill(0xffffff);
    graphics.moveTo(-size * c30, size * 0.5);
    graphics.lineTo(size * c30, size * 0.5);
    graphics.lineTo(0, -size);
    graphics.drawRect(-size * 0.5, size * 0.6, size, size * 0.3);
    graphics.endFill();
  }

  public function init():void {
    x = stage.stageWidth / 2;
    y = stage.stageHeight / 2;
  }

  public function update(dt:Number):void {
    rotation += ((turnRight ? 1 : 0) - (turnLeft ? 1 : 0)) * turnSpeed * dt;

    var reloading:Boolean = vecLen(x - stage.stageWidth / 2, y - stage.stageHeight / 2) < starSize;

    if (throttle || reloading) {
      vx += Math.sin(rotation * Math.PI / 180) * acceleration * dt;
      vy -= Math.cos(rotation * Math.PI / 180) * acceleration * dt;
    }

    if (borderHit(x, vx, size, stage.stageWidth)) {
      vx *= -1;
    }

    if (borderHit(y, vy, size, stage.stageHeight)) {
      vy *= -1;
    }

    x += vx * dt;
    y += vy * dt;

    energy = reloading ? Math.min(1, energy + refillRate * dt) : Math.max(0, energy - depletionRate * dt);
    transform.colorTransform = new ColorTransform(energy, 0.3 + energy * 0.7, 0.6 + energy * 0.4);
  }

}

internal class Sunflare extends Sprite {

  public static const numFlares:int = 3;
  public static const bsize:int = 256;
  public static const maxScale:Number = starSize * 4 / bsize;

  public function Sunflare():void {
    var bmd:BitmapData = new BitmapData(bsize, bsize);
    bmd.perlinNoise(16, 16, 2, 1, false, true, BitmapDataChannel.ALPHA, true);
    bmd.colorTransform(new Rectangle(0, 0, bsize, bsize),
		       new ColorTransform(1, 1, 1, 2.5, 0, 0, 0, -255));
    for (var i:int = 0; i < bsize; i++) {
      for (var j:int = 0; j < bsize; j++) {
	var a:uint = (bmd.getPixel32(i, j) >> 24) & 0xff;
	var d:uint = Math.max(0, 255 - vecLen(i - bsize / 2, j - bsize / 2) * 512 / bsize);
	bmd.setPixel32(i, j, (((a * d) >> 8) << 24) | 0xffffff);
      }
    }

    for (i = 0; i < numFlares; i++) {
      var flare:Shape = new Shape();
      flare.graphics.beginBitmapFill(bmd, new Matrix(1, 0, 0, 1, -bsize / 2, -bsize / 2));
      flare.graphics.drawRect(-bsize / 2, -bsize / 2, bsize, bsize);
      flare.graphics.endFill();
      flare.scaleX = maxScale * (i + 1) / numFlares;
      flare.scaleY = maxScale * (i + 1) / numFlares;
      flare.rotation = 360 * i / numFlares;
      flare.alpha = 1 - flare.scaleX / maxScale;
      addChild(flare);
    }
  }

  public function update(dt:Number):void {
    for (var i:int = 0; i < numChildren; i++) {
      var flare:Shape = getChildAt(i) as Shape;
      flare.rotation += 50 * dt * flare.alpha;
      flare.scaleX += maxScale * 0.5 * dt;
      if (flare.scaleX > maxScale) {
	flare.scaleX = 0;
      }
      flare.scaleY = flare.scaleX;
      flare.alpha = 1 - flare.scaleX / maxScale;
    }
  }

}

function borderHit(p:Number, v:Number, s:Number, l:Number):Boolean {
  return ((p < s) && (v < 0)) || ((p > l - s) && (v > 0))
}

function vecLen(vx:Number, vy:Number):Number {
  return Math.sqrt(vx * vx + vy * vy);
}
