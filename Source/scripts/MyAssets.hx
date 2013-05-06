package scripts;

import haxe.xml.Fast;
import nme.Assets;
import com.stencyl.AssetLoader;
import com.stencyl.Engine;

class MyAssets implements AssetLoader
{
	//Game
	public static var landscape:Bool = true;
	public static var autorotate:Bool = true;
	public static var stretchToFit:Bool = false;
	public static var stageWidth:Int = 480;
	public static var stageHeight:Int = 320;
	public static var initSceneID:Int = 0;
	public static var physicsMode:Int = 0;
	public static var gameScale:Float = 1;
	public static var gameImageBase:String = "1x";
	public static var antialias:Bool = true;
	
	//APIs
	public static var adPositionBottom:Bool = true;
	public static var whirlID:String = "";
	public static var mochiID:String = "";
	public static var cpmstarID:String = "";
	public static var newgroundsID:String = "";
	public static var newgroundsKey:String = "";
	
	//Other
	public static var releaseMode:Bool = false;
	public static var showConsole:Bool = true;
	public static var debugDraw:Bool = true;
	public static var always1x:Bool = false;
	
	//Keys
	public static var androidPublicKey:String = "";
	
	public function new()
	{
	}
	
	public function loadResources(resourceMap:Hash<Dynamic>):Void
	{
		//Actor: Pronger
		resourceMap.set("1-0.png", Assets.getBitmapData("assets/graphics/" + Engine.IMG_BASE + "/1-0.png"));
		
		//Background
		resourceMap.set("18-0.png", Assets.getBitmapData("assets/graphics/" + Engine.IMG_BASE + "/18-0.png"));
		
		//Tileset
		resourceMap.set("19.png", Assets.getBitmapData("assets/graphics/" + Engine.IMG_BASE + "/19.png"));
	}
	
	public function loadScenes(scenesXML:IntHash<Fast>, scenesTerrain:IntHash<Dynamic>):Void
	{
		//Scene
		scenesXML.set(0, new Fast(Xml.parse(Assets.getText("assets/data/scene-0.xml")).firstElement()));
		scenesTerrain.set(0, Assets.getBytes("assets/data/scene-0.scn"));
	}
}