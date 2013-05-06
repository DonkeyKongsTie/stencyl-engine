package com.stencyl.models.collision;

import com.stencyl.models.Actor;
import nme.display.Graphics;
import nme.geom.Point;

typedef MaskCallback = Dynamic -> Bool;

/**
 * Base class for Entity collision masks.
 */
class Mask
{
	/**
	 * The parent Entity of this mask.
	 */
	public var parent:Actor;

	/**
	 * The parent Masklist of the mask.
	 */
	public var list:Masklist;
	
	public var solid:Bool;

	/**
	 * Constructor.
	 */
	public function new()
	{
		solid = true;
		_class = Type.getClassName(Type.getClass(this));
		_check = new Hash<MaskCallback>();
		_check.set(Type.getClassName(Mask), collideMask);
		_check.set(Type.getClassName(Masklist), collideMasklist);	
	}

	/**
	 * Checks for collision with another Mask.
	 * @param	mask	The other Mask to check against.
	 * @return	If the Masks overlap.
	 */
	public function collide(mask:Mask):Bool
	{
		if (parent == null)
		{
			throw "Mask must be attached to a parent Entity";
		}
		
		var cbFunc:MaskCallback = _check.get(mask._class);
		if (cbFunc != null) return cbFunc(mask);

		cbFunc = mask._check.get(_class);
		if (cbFunc != null) return cbFunc(this);

		return false;
	}

	/** @private Collide against an Entity. */
	private function collideMask(other:Mask):Bool
	{
		if (parent.colX + parent.cacheWidth >= other.parent.colX
			&& parent.colY + parent.cacheHeight >= other.parent.colY
			&& parent.colX <= other.parent.colX + other.parent.cacheWidth
			&& parent.colY <= other.parent.colY + other.parent.cacheHeight)
		{
			var info:CollisionInfo = new CollisionInfo();
			
			info.solidCollision = solid && other.solid;
			info.maskA = this;
			info.maskB = other;			
			
			if (parent.isLightweight)
			{
				parent.addCollision(info);
			}
			
			if (other.parent.isLightweight)
			{
				other.parent.addCollision(info);
			}
			
			return true;				
		}
		
		return false;
	}

	private function collideMasklist(other:Masklist):Bool
	{
		return other.collide(this);
	}

	/** @private Assigns the mask to the parent. */
	public function assignTo(parent:Actor)
	{
		this.parent = parent;
		if (parent != null) update();
	}

	/**
	 * Override this
	 */
	public function debugDraw(graphics:Graphics, scaleX:Float, scaleY:Float):Void
	{

	}

	/** Updates the parent's bounds for this mask. */
	public function update()
	{

	}

	public inline function projectMask(axis:Point, collisionInfo:CollisionInfo):Void
	{
		var cur:Float,
			max:Float = -9999999999.,
			min:Float = 9999999999.;

		cur = -parent.originX * axis.x - parent.originY * axis.y;
		if (cur < min)
			min = cur;
		if (cur > max)
			max = cur;

		cur = (-parent.originX + parent.cacheWidth) * axis.x - parent.originY * axis.y;
		if (cur < min)
			min = cur;
		if (cur > max)
			max = cur;

		cur = -parent.originX * axis.x + (-parent.originY + parent.cacheHeight) * axis.y;
		if (cur < min)
			min = cur;
		if (cur > max)
			max = cur;

		cur = (-parent.originX + parent.cacheWidth) * axis.x + (-parent.originY + parent.cacheHeight)* axis.y;
		if (cur < min)
			min = cur;
		if (cur > max)
			max = cur;

		collisionInfo.min = min;
		collisionInfo.max = max;
	}

	// Mask information.
	private var _class:String;
	private var _check:Hash<MaskCallback>;
}