package {

  import flash.display.*;
  import flash.events.*;
  import flash.utils.*;

  public class LBR extends Sprite {

    // Time step per frame in seconds
    private const dt:Number = 0.02;

    public function LBR():void {
      stage.frameRate = 1 / dt;
      stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function onEnterFrame(e:Event):void {
      update();
      redraw();
    }

    private function update():void {
    }

    private function redraw():void {
      graphics.clear();
    }

  }

}
