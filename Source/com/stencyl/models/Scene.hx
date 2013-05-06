package com.stencyl.models;

import com.stencyl.io.BackgroundReader;
import com.stencyl.io.ActorTypeReader;
import com.stencyl.io.SpriteReader;

import com.stencyl.models.scene.Tile;
import com.stencyl.models.scene.Tileset;
import com.stencyl.models.scene.TileLayer;

import com.stencyl.models.background.ColorBackground;
import com.stencyl.models.scene.ActorInstance;
import com.stencyl.models.scene.RegionDef;
import com.stencyl.models.scene.TerrainDef;
import com.stencyl.models.scene.Wireframe;
import com.stencyl.models.collision.Mask;
import com.stencyl.behavior.BehaviorInstance;

import nme.geom.Point;
import box2D.collision.shapes.B2Shape;
import box2D.collision.shapes.B2EdgeShape;
import box2D.collision.shapes.B2CircleShape;
import box2D.collision.shapes.B2PolygonShape;
import box2D.dynamics.joints.B2Joint;
import box2D.dynamics.joints.B2JointDef;
import box2D.dynamics.joints.B2DistanceJointDef;
import box2D.dynamics.joints.B2RevoluteJointDef;
import box2D.dynamics.joints.B2LineJointDef;
import box2D.common.math.B2Vec2;
import box2D.common.math.B2Math;

import haxe.xml.Fast;
import com.stencyl.Engine;
import com.stencyl.utils.Utils;

import nme.geom.Rectangle;
import nme.utils.ByteArray;
import com.stencyl.utils.PolyDecompBayazit;

class Scene
{
	public var ID:Int;
	public var name:String;
	
	public var sceneWidth:Int;
	public var sceneHeight:Int;
	
	public var tileWidth:Int;
	public var tileHeight:Int;
	
	public var gravityX:Float;
	public var gravityY:Float;
	
	public var eventID:Int;
	
	public var colorBackground:Background;
	
	public var bgs:Array<Int>;
	public var fgs:Array<Int>;
	
	public var terrain:IntHash<TileLayer>;
	public var actors:IntHash<ActorInstance>;
	public var behaviorValues:Hash<BehaviorInstance>;
	
	//Box2D
	public var wireframes:Array<Wireframe>;
	public var joints:IntHash<B2JointDef>;
	public var regions:IntHash<RegionDef>;
	public var terrainRegions:IntHash<TerrainDef>;
	
	public var animatedTiles:Array<Tile>;
	
	public function new(ID:Int, name:String, xml:Fast)
	{
		this.ID = ID;
		this.name = name;
		
		var numLayers:Int = Std.parseInt(xml.att.depth);
		
		sceneWidth = Std.parseInt(xml.att.width);
		sceneHeight = Std.parseInt(xml.att.height);
		
		tileWidth = Std.parseInt(xml.att.tilew);
		tileHeight = Std.parseInt(xml.att.tileh);
		
		gravityX = Std.parseFloat(xml.att.gravx);
		gravityY = Std.parseFloat(xml.att.gravy);
								
		animatedTiles = new Array<Tile>();
		
		bgs = readBackgrounds(xml.node.backgrounds.elements);
		fgs = readBackgrounds(xml.node.foregrounds.elements);
					
		colorBackground = new ColorBackground(0xFFFFFFFF);
		
		for(e in xml.elements)
		{
			if(e.name == "color-bg" || e.name == "grad-bg")
			{
				colorBackground = cast(new BackgroundReader().read(0, 0, e.name, "", e), Background);
				break;
			}
		}
		
		actors = readActors(xml.node.actors.elements);
		behaviorValues = ActorTypeReader.readBehaviors(xml.node.snippets);
		
		var eventSnippetID = "";
		
		try
		{
			eventSnippetID = xml.att.eventsnippetid;
		}
		
		catch(e:String)
		{
		}

		if(eventSnippetID != "")
		{
			eventID = Std.parseInt(eventSnippetID);
			
			if(eventID > -1)
			{
				behaviorValues.set(eventSnippetID, new BehaviorInstance(eventID, new Hash<Dynamic>()));
			}
		}
		
		joints = readJoints(xml.node.joints.elements);
		regions = readRegions(xml.node.regions.elements);
		terrainRegions = readTerrainRegions(xml.node.terrainRegions.elements);
		
		wireframes = readWireframes(xml.node.terrain.elements);
		
		#if js
		var rawLayers = readRawLayers(nme.Assets.getText("assets/data/scene-" + ID + ".txt"), numLayers);
		#end
		
		#if !js
		var rawLayers = readRawLayers(Data.get().scenesTerrain.get(ID), numLayers);
		#end
		
		terrain = readLayers(xml.node.layers.elements, rawLayers);
	}
	
	public function readRegions(list:Iterator<Fast>):IntHash<RegionDef>
	{
		var map = new IntHash<RegionDef>();
		
		for(e in list)
		{
			var r:RegionDef = readRegion(e);
			map.set(r.ID, r);
		}
		
		return map;
	}
	
	public function readRegion(e:Fast):RegionDef
	{
		var type = e.att.type;
		var elementID = Std.parseInt(e.att.id);
		var name = e.att.name;
		var region:RegionDef;
		
		var x:Float = Engine.toPhysicalUnits(Std.parseFloat(e.att.x));
		var y:Float = Engine.toPhysicalUnits(Std.parseFloat(e.att.y));
		
		var shape:B2Shape = null;
		var ps = new Array<B2PolygonShape>();
		shapeList = new Array<B2Shape>();
		var decompParams:Array<String>;
		
		if(type == "box")
		{
			var w:Float = Engine.toPhysicalUnits(Std.parseFloat(e.att.w)); 
			var h:Float = Engine.toPhysicalUnits(Std.parseFloat(e.att.h)); 
			
			if(Engine.NO_PHYSICS)
			{
				w = Std.parseFloat(e.att.w);
				h = Std.parseFloat(e.att.h);
			
				region = new RegionDef(shapeList, elementID, name, x, y, 0, new Rectangle(0, 0, w, h));
			}
			
			else
			{
				var box = new B2PolygonShape();
				box.setAsBox(w/2, h/2);
				shape = box;
				shapeList[0] = shape;
				region = new RegionDef(shapeList, elementID, name, x, y);
			}
		}
		
		else if(type == "poly")
		{
			var w = Std.parseFloat(e.att.w);
			var h = Std.parseFloat(e.att.h);
			var pts = null;
			
			if(e.has.pts)
			{
				pts = e.att.pts;
			}
			
			var shapeType:String = "polyregion";
			
			//backwards compatibility for box regions
			if(pts == null || Engine.NO_PHYSICS)
			{
				if(Engine.NO_PHYSICS)
				{
					w = Std.parseFloat(e.att.w);
					h = Std.parseFloat(e.att.h);
				
					region = new RegionDef(shapeList, elementID, name, x, y, 0, new Rectangle(0, 0, w, h));
				}
				
				else
				{
					var box = new B2PolygonShape();
					box.setAsBox(w/2, h/2);
					shape = box;
					shapeList[0] = shape;
					region = new RegionDef(shapeList, elementID, name, x, y);
				}
				
				return region;
			}

			//Polygon Decomposition
			currX = x;
			currY = y;
			currW = w;
			currH = h;
			
			var shapeParams = pts.split(",");
			
			var points = new Array<Point>();
			var numVertices = Std.parseFloat(shapeParams[0]);
			var vIndex:Int = 0;
			var i:Int = 0;
				
			while(vIndex < numVertices)
			{	
				points.push(new Point(Std.parseFloat(shapeParams[i+1]), Std.parseFloat(shapeParams[i + 2])));
				vIndex++;
				i += 2;
			}
			
			var decomp = new PolyDecompBayazit(points);
			decomp.decompose(addPolygonRegion);
			region = new RegionDef(shapeList, elementID, name, x, y);
		}
			
		else
		{
			var radius:Float = Engine.toPhysicalUnits(Std.parseFloat(e.att.rad));
			
			if(Engine.NO_PHYSICS)
			{
				radius = Std.parseFloat(e.att.rad);
				
				region = new RegionDef(shapeList, elementID, name, x, y, 0, new Rectangle(0, 0, radius*2, radius*2));
			}
			
			else
			{
				shape = new B2CircleShape();
				shape.m_radius = radius;
				shapeList[0] = shape;
				region = new RegionDef(shapeList, elementID, name, x, y);
			}		
		}
		
		return region;
	}
	
	var shapeList:Array<B2Shape>;
	var currX:Float;
	var currY:Float;
	var currW:Float;
	var currH:Float;
	
	function addPolygonRegion(p:PolyDecompBayazit)
	{
   		//trace("THE POLY: " + p.points);
   		
   		var loX:Float = B2Math.MAX_VALUE;
		var loY:Float = B2Math.MAX_VALUE;
		var hiX:Float = 0;
		var hiY:Float = 0;

		var decompParams:Array<String> = new Array();
		decompParams[0] = "" + p.points.length;

		for(j in 0...p.points.length)
		{
			loX = Math.min(loX, p.points[j].x);
			loY = Math.min(loY, p.points[j].y);
			hiX = Math.min(hiX, p.points[j].x);
			hiY = Math.min(hiY, p.points[j].y);
			decompParams.push("" + p.points[j].x);
			decompParams.push("" + p.points[j].y);
		}
		
		var localWidth:Float;
		var localHeight:Float;
		
		localWidth = hiX - loX;
		localHeight = hiY - loY;
		loX = Engine.toPhysicalUnits(loX);
		loY = Engine.toPhysicalUnits(loY);
		
		var polyShape = cast(SpriteReader.createShape("polyregion", decompParams, currX, currY, currW, currH), B2PolygonShape);
		shapeList.push(polyShape);
	}
	
	function addPolygonTerrain(p:PolyDecompBayazit)
	{
		//trace("THE POLY: " + p.points);
		
		var loX:Float = B2Math.MAX_VALUE;
		var loY:Float = B2Math.MAX_VALUE;
		var hiX:Float = 0;
		var hiY:Float = 0;

		var decompParams:Array<String> = new Array();
		decompParams[0] = "" + p.points.length;

		for(j in 0...p.points.length)
		{
			loX = Math.min(loX, p.points[j].x);
			loY = Math.min(loY, p.points[j].y);
			hiX = Math.min(hiX, p.points[j].x);
			hiY = Math.min(hiY, p.points[j].y);
			decompParams.push("" + p.points[j].x);
			decompParams.push("" + p.points[j].y);
		}
		
		var localWidth:Float;
		var localHeight:Float;
		
		localWidth = hiX - loX;
		localHeight = hiY - loY;
		loX = Engine.toPhysicalUnits(loX);
		loY = Engine.toPhysicalUnits(loY);
		
		var polyShape = cast(SpriteReader.createShape("polyregion", decompParams, currX, currY, currW, currH), B2PolygonShape);
		shapeList.push(polyShape);
	}
	
	public function readTerrainRegions(list:Iterator<Fast>):IntHash<TerrainDef>
	{
		var map = new IntHash<TerrainDef>();
		
		for(e in list)
		{
			var r:TerrainDef = readTerrainRegion(e);
			map.set(r.ID, r);
		}
		
		return map;
	}
	
	public function readTerrainRegion(e:Fast):TerrainDef
	{
		var type = e.att.type;
		var elementID = Std.parseInt(e.att.id);
		var name = e.att.name;
		var group = Std.parseInt(e.att.group);
		var terrainRegion:TerrainDef;
		
		var x:Float = Engine.toPhysicalUnits(Std.parseFloat(e.att.x));
		var y:Float = Engine.toPhysicalUnits(Std.parseFloat(e.att.y));
		var r:Int = Std.parseInt(e.att.r);
		var g:Int = Std.parseInt(e.att.g);
		var b:Int = Std.parseInt(e.att.b);
		var fillColor = Utils.getColorRGB(r, g, b);
		
		var shape:B2Shape = null;
		var ps = new Array<B2PolygonShape>();
		shapeList = new Array<B2Shape>();
		var decompParams:Array<String>;
		
		if(type == "box")
		{
			var w:Float = Engine.toPhysicalUnits(Std.parseFloat(e.att.w)); 
			var h:Float = Engine.toPhysicalUnits(Std.parseFloat(e.att.h)); 
			var box = new B2PolygonShape();
			box.setAsBox(w/2, h/2);
			shape = box;
			shapeList[0] = shape;
			terrainRegion= new TerrainDef(shapeList, elementID, name, x, y, group, fillColor);
		}
		
		else if(type == "poly")
		{
			var w = Std.parseFloat(e.att.w);
			var h = Std.parseFloat(e.att.h);
			
			var shapeType:String = "polyregion";
			var shapeParams = e.att.pts.split(",");

			//Polygon Decomposition
			currX = x;
			currY = y;
			currW = w;
			currH = h;
			
			var points = new Array<Point>();
			var numVertices = Std.parseFloat(shapeParams[0]);
			var vIndex:Int = 0;
			var i:Int = 0;
				
			while(vIndex < numVertices)
			{	
				points.push(new Point(Std.parseFloat(shapeParams[i+1]), Std.parseFloat(shapeParams[i + 2])));
				vIndex++;
				i += 2;
			}
			
			var decomp = new PolyDecompBayazit(points);
			decomp.decompose(addPolygonTerrain);
			terrainRegion = new TerrainDef(shapeList, elementID, name, x, y, group, fillColor);
		}
		
		else
		{
			var radius:Float = Engine.toPhysicalUnits(Std.parseFloat(e.att.rad));
			shape = new B2CircleShape();
			shape.m_radius = radius;
			shapeList[0] = shape;
			terrainRegion = new TerrainDef(shapeList, elementID, name, x, y, group, fillColor);
		}
		
		return terrainRegion;
	}
	
	public function readJoints(list:Iterator<Fast>):IntHash<B2JointDef>
	{
		var map = new IntHash<B2JointDef>();
		
		for(e in list)
		{
			var j = readJoint(e);
			map.set(j.ID, j);
		}
		
		return map;
	}
	
	public function readJoint(e:Fast):B2JointDef
	{
		var type:String = e.name;
		var elementID = Std.parseInt(e.att.id);
		
		var a1 = Std.parseInt(e.att.a1);
		var a2 = Std.parseInt(e.att.a2);
		var collide = Utils.toBoolean(e.att.collide);
		
		if(type == "STICK_JOINT")
		{
			var j = new B2DistanceJointDef();
			
			j.ID = elementID;
			j.actor1 = a1;
			j.actor2 = a2;
			j.localAnchorA = null;
			j.localAnchorB = null;
			j.collideConnected = collide;
			
			//---
			
			j.dampingRatio = Std.parseFloat(e.att.damping);
			j.frequencyHz = Std.parseFloat(e.att.freq);
			
			return j;
		}
		
		else if(type == "HINGE_JOINT")
		{
			var j2 = new B2RevoluteJointDef();
			
			j2.ID = elementID;
			j2.actor1 = a1;
			j2.actor2 = a2;
			j2.localAnchorA = null;
			j2.localAnchorB = null;
			j2.collideConnected = collide;
			
			//---
			
			j2.enableLimit = Utils.toBoolean(e.att.limit);
			j2.enableMotor = Utils.toBoolean(e.att.motor);
			j2.lowerAngle = Std.parseFloat(e.att.lower);
			j2.upperAngle = Std.parseFloat(e.att.upper);
			j2.maxMotorTorque = Std.parseFloat(e.att.torque);
			j2.motorSpeed = Std.parseFloat(e.att.speed);
			
			return j2;
		}
		
		else if(type == "SLIDING_JOINT")
		{
			var j3 = new B2LineJointDef();
			
			j3.ID = elementID;
			j3.actor1 = a1;
			j3.actor2 = a2;
			j3.localAnchorA = null;
			j3.localAnchorB = null;
			j3.collideConnected = collide;
			
			//---
			
			j3.enableLimit = Utils.toBoolean(e.att.limit);
			j3.enableMotor = Utils.toBoolean(e.att.motor);
			j3.lowerTranslation = Std.parseFloat(e.att.lower);
			j3.upperTranslation = Std.parseFloat(e.att.upper);
			j3.maxMotorForce = Std.parseFloat(e.att.force);
			j3.motorSpeed = Std.parseFloat(e.att.speed);
			j3.localAxisA.x = Std.parseFloat(e.att.x);
			j3.localAxisA.y = Std.parseFloat(e.att.y);
			
			return j3;
		}
		
		trace("Error: unsuppported joint type: " + type);
		
		return null;
	}

	public function readLayers(list:Iterator<Fast>, rawLayers:IntHash<TileLayer> = null):IntHash<TileLayer>
	{
		var map = new IntHash<TileLayer>();
		
		for(e in list)
		{
			var eid = Std.parseInt(e.att.id);
		
			map.set(eid, rawLayers.get(eid));
			
			var layer:TileLayer = map.get(eid);
			
			if(layer != null)
			{
				layer.name = e.att.name;
				layer.zOrder = Std.parseInt(e.att.order);
			}
			
			else
			{
				var dummy = new TileLayer(eid, Std.parseInt(e.att.order), this, Std.int(Math.floor(sceneWidth / tileWidth)), Std.int(Math.floor(sceneHeight / tileHeight)));
				map.set(eid, dummy);
			}
		}
		
		return map;
	}
	
	#if js
	public function readRawLayers(data:String, numLayers:Int):IntHash<TileLayer>
	{
		var map = new IntHash<TileLayer>();

		if(data != null)
		{
			var split = data.split("~");
		
			for(i in 0...numLayers)
			{
				var newLayer = readRawLayer(split[i]);
				map.set(newLayer.layerID, newLayer);
			}
		}
				
		return map;
	}
	
	public function readRawLayer(data:String):TileLayer
	{	
		var split = data.split("#");
		var width = Std.int(Math.floor(sceneWidth / tileWidth));
		var height = Std.int(Math.floor(sceneHeight / tileHeight));
		
		var layerID = Std.parseInt(split[0]);
		var zOrder = Std.parseInt(split[1]);

		var layer = new TileLayer(layerID, zOrder, this, width, height);
		
		var row = 0;
		var col = 0;
		
		//Grid for non-Box2D games
		var grid = new com.stencyl.models.collision.Grid(sceneWidth, sceneHeight, tileWidth, tileHeight);
		layer.grid = grid;

		split = split[2].split("|");
		
		for(i in 0...split.length)
		{
			if(split[i] == "" || split[i] == "E" || split[i] == "EMPTY")
			{
				continue;
			}
			
			var item = split[i].split(",");
		
			var tilesetID:Int = Std.parseInt(item[0]);
			var tileID:Int = Std.parseInt(item[1]);
			var runLength:Int = Std.parseInt(item[2]);
			
			var tset:Tileset = null;

			if(tilesetID != -1)
			{
				tset = cast(Data.get().resources.get(tilesetID), Tileset);
			}
			
			for(runIndex in 0...runLength)
			{
				if(tset == null || tileID < 0 || tset == null)
				{
					layer.setTileAt(row, col, null);
				}
				
				else
				{
					layer.setTileAt(row, col, tset.tiles[tileID]);
					
					if(tset.tiles[tileID].collisionID > 0)
					{
						grid.setTile(col, row, true);
					}

					var tile = tset.tiles[tileID];
					
					if(tile != null && tile.pixels != null)
					{
						var inList:Bool = false;
						
						for(checkTile in animatedTiles)
						{
							inList = (checkTile == tile);
						
							if(inList) 
							{
								break;
							}
						}
						
						if(!inList)
						{
							animatedTiles.push(tile);
						}
					}
				}
				
				col++;
				
				if(col >= width)
				{
					col = 0;
					row++;
				}
			}
		}
		
		return layer;
	}
	#end
	
	#if !js
	public function readRawLayers(bytes:ByteArray, numLayers:Int):IntHash<TileLayer>
	{
		var map = new IntHash<TileLayer>();
		var layerHeaders = new Array<Int>();
		
		if(bytes != null)
		{
			for(i in 0...numLayers)
			{
				layerHeaders[i] = bytes.readInt();
			}
			
			for(i in 0...numLayers)
			{
				var newLayer = readRawLayer(bytes, layerHeaders[i]);
				map.set(newLayer.layerID, newLayer);
			}
		}
				
		return map;
	}
	
	public function readRawLayer(bytes:ByteArray, length:Int):TileLayer
	{	
		var width = Std.int(Math.floor(sceneWidth / tileWidth));
		var height = Std.int(Math.floor(sceneHeight / tileHeight));
		
		var layerID = bytes.readInt();
		length -= 4;
		
		var zOrder = bytes.readInt();
		length -= 4;
		
		var layer = new TileLayer(layerID, zOrder, this, width, height);
		
		var row = 0;
		var col = 0;
		
		var RLETILE_BYTE_COUNT = 8;
		var numChunks:Int = Std.int(length / RLETILE_BYTE_COUNT);
		
		//Grid for non-Box2D games - TODO: Don't make this for Box2D games?
		var grid = new com.stencyl.models.collision.Grid(sceneWidth, sceneHeight, tileWidth, tileHeight);
		layer.grid = grid;
		
		//Testing tiles in Universal test app
		/*layer.setTileAt(0, 0, (cast(Data.get().resources.get(19), Tileset)).tiles[6]);
		layer.setTileAt(1, 1, (cast(Data.get().resources.get(19), Tileset)).tiles[6]);
		layer.setTileAt(2, 2, (cast(Data.get().resources.get(19), Tileset)).tiles[6]);
		layer.setTileAt(3, 3, (cast(Data.get().resources.get(19), Tileset)).tiles[6]);*/		

		for(i in 0...numChunks)
		{
			//Unused value we have to keep for compatibility reasons.
			bytes.readShort();
			
			var tilesetID:Int = bytes.readShort();
			var tileID:Int = bytes.readShort();
			var runLength:Int = bytes.readShort();
			
			var tset:Tileset = null;
			
			if(tilesetID != -1)
			{
				var temp = Data.get().resources.get(tilesetID);
				
				if(temp != null)
				{
					tset = cast(Data.get().resources.get(tilesetID), Tileset);
				}
			}
			
			for(runIndex in 0...runLength)
			{
				if(tset == null || tileID < 0 || tset == null)
				{
					layer.setTileAt(row, col, null);
				}
				
				else
				{
					var tile = tset.tiles[tileID];
					
					if(tile == null)
					{
						layer.setTileAt(row, col, null);
					}
					
					else
					{
						layer.setTileAt(row, col, tile);

						if(tile.collisionID > 0)
						{
							grid.setTile(col, row, true);
						}
						
						if(tile.pixels != null)
						{
							var inList:Bool = false;
							
							for(checkTile in animatedTiles)
							{
								if(inList = (checkTile == tile)) 
									break;
							}
							
							if(!inList)
							{
								animatedTiles.push(tile);
							}
						}
					}	
				}
				
				col++;
				
				if(col >= width)
				{
					col = 0;
					row++;
				}
			}
		}
		
		return layer;
	}
	#end
	
	public function readBackgrounds(list:Iterator<Fast>):Array<Int>
	{
		var map:Array<Int> = new Array<Int>();
		
		for(e in list)
		{
			map.push(Std.parseInt(e.att.id));
		}
		
		return map;
	}
	
	private static var MAX_VERTICES:Int = 200;
	
	public function readWireframes(list:Iterator<Fast>):Array<Wireframe>
	{
		var map = new Array<Wireframe>();
		
		for(e in list)
		{
			var x = Std.parseFloat(e.att.x);
			var y = Std.parseFloat(e.att.y);
			
			var shapeType:String = "wireframe";
			var shapeParams:Array<String> = e.att.pts.split(",");
						
			//TODO: Does not work
			if(Engine.NO_PHYSICS)
			{
				/*var points = new Array<Point>();
				
				var i = 1;
				
				while(i < shapeParams.length)
				{
					points.push(new Point(Std.parseFloat(shapeParams[i]), Std.parseFloat(shapeParams[i+1])));
					i += 2;
				}
				
				var shape2 = new Polygon(points);
				
				map.push
				(
					new Wireframe
					(
						x,
						y, 
						shape2.width, 
						shape2.height,
						null,
						shape2
					)
				);*/
				
				//Broken - Use the simple grid instead
			}
			
			else
			{
				var shapeData = cast(SpriteReader.createShape(shapeType, shapeParams, x, y), IntHash<Dynamic>);
			
				map.push
				(
					new Wireframe
					(
						Engine.toPhysicalUnits(x), 
						Engine.toPhysicalUnits(y), 
						shapeData.get(1), 
						shapeData.get(2),
						shapeData.get(0),
						null
					)
				);		
			}
		}
		
		return map;
	}
	
	public function readActors(list:Iterator<Fast>):IntHash<ActorInstance>
	{
		var map:IntHash<ActorInstance> = new IntHash<ActorInstance>();
		
		for(e in list)
		{
			var ai:ActorInstance = readActorInstance(e);
			
			if(ai != null)
			{
				map.set(Std.parseInt(e.att.aid), ai);
			}
		}
		
		return map;
	}
	
	public function readActorInstance(xml:Fast):ActorInstance
	{
		var elementID:Int = Std.parseInt(xml.att.aid);
		var x:Int = Std.parseInt(xml.att.x);
		var y:Int = Std.parseInt(xml.att.y);
		
		var scaleX:Float = 1;
		var scaleY:Float = 1;
		
		try
		{
			scaleX = Std.parseFloat(xml.att.sx);
			scaleY = Std.parseFloat(xml.att.sy);
		}
		
		catch(e:String)
		{
		}
		
		var layerID:Int = Std.parseInt(xml.att.z);
		var angle:Int = Std.parseInt(xml.att.a);
		var groupID:Int =  Std.parseInt(xml.att.group);
		var actorID:Int = Std.parseInt(xml.att.id);
		var isCustomized:Bool = Utils.toBoolean(xml.att.c);
		
		var behaviors:Hash<BehaviorInstance> = null;
		
		if(isCustomized)
		{
			behaviors = ActorTypeReader.readBehaviors(xml.node.snippets);
		}
		
		if (scaleX == 0 || scaleY == 0)
		{
			scaleX = 1;
			scaleY = 1;
		}
		
		if(!isCustomized)
		{
			behaviors = null;
		}
		
		if(Data.get().resources.get(actorID) == null)
		{
			return null;
		}
		
		var ai:ActorInstance = new ActorInstance
		(
			elementID,
			x,
			y,
			scaleX,
			scaleY,
			layerID,
			angle,
			groupID,
			actorID,
			behaviors,
			isCustomized
		);
		
		if(ai.actorType != null)
		{
			ai.groupID = ai.actorType.groupID;
		}
		
		return ai;
	}
	
	public function getID():Int
	{
		return ID;
	}
}