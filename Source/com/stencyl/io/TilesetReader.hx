package com.stencyl.io;

import haxe.xml.Fast;
import com.stencyl.utils.Utils;

import com.stencyl.models.Resource;
import com.stencyl.models.scene.Tileset;
import com.stencyl.models.scene.Tile;

class TilesetReader implements AbstractReader
{
	public function new() 
	{
	}		

	public function accepts(type:String):Bool
	{
		return type == "tileset";
	}
	
	public function read(ID:Int, atlasID:Int, type:String, name:String, xml:Fast):Resource
	{
		//trace("Reading Tileset (" + ID + ") - " + name);

		var framesAcross:Int = Std.parseInt(xml.att.across);
		var framesDown:Int = Std.parseInt(xml.att.down);
		var tileWidth:Int = Std.parseInt(xml.att.tw);
		var tileHeight:Int = Std.parseInt(xml.att.th);
		var tiles:Array<Tile> = new Array<Tile>();

		var tset:Tileset = new Tileset(ID, atlasID, name, framesAcross, framesDown, tileWidth, tileHeight, tiles);
		
		for(e in xml.elements)
		{
			tiles[Std.parseInt(e.att.id)] = readTile(e, tset);
		}
		
		tset.setupTilesheet();

		return tset;
	}
	
	public function readTile(xml:Fast, parent:Tileset):Tile
	{
		var tileID:Int = Std.parseInt(xml.att.id);
		var collisionID:Int = Std.parseInt(xml.att.collision);
		
		//Always single for now!
		var frameID:Int = Std.parseInt(xml.att.frames);
		
		//Animated Tiles
		var imgData:Dynamic = null;
		var durations:Array<Int> = new Array<Int>();
		var counter:Int = 0;
		
		var s:String = xml.att.durations;
		var frames:Array<String> = s.split(",");
		
		for(f in frames)
		{
			//Round to the nearest 10ms - there's no more granularity than this and makes it much easier for me.
			durations[counter] = Std.parseInt(f);
			
			durations[counter] =  Math.floor(durations[counter] / 10);
			durations[counter] *= 10;
			
			counter++;
		}

		return new Tile(tileID, collisionID, frameID, durations, parent);
	}
}
