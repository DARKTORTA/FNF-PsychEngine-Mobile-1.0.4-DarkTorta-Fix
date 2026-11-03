package backend;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;

import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.system.System;
import openfl.geom.Rectangle;

import lime.utils.Assets;
import flash.media.Sound;

import haxe.Json;


#if MODS_ALLOWED
import backend.Mods;
#end

@:access(openfl.display.BitmapData)
class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = ['assets/shared/music/freakyMenu.$SOUND_EXT', 'assets/shared/mobile/touchpad/bg.png'];
	// MERGED: Beep anti-freeze + anti-diamantitos sticker
	public static function clearUnusedMemory()
	{
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// FIX STICKER: no borrar stickers mientras están en pantalla (anti-diamantitos 5.6.1)
			if(key.contains('sticker') || key.contains('transitionSwag') || key.contains('asbelin') || key.contains('stickers-set')) continue;
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				destroyGraphic(currentTrackedAssets.get(key)); // get rid of the graphic
				currentTrackedAssets.remove(key); // and remove the key from local cache map
			}
		}

		// BEEP FIX: solo GC si RAM > 800MB y sin congelar (run(false))
		var mem:Float = System.totalMemory / 1024 / 1024;
		if(mem > 800)
		{
			System.gc();
			#if cpp
			cpp.NativeGc.run(false);
			#end
		}
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			// FIX STICKER: no borrar stickers en clearStoredMemory tampoco
			if(key.contains('sticker') || key.contains('transitionSwag') || key.contains('asbelin') || key.contains('stickers-set')) continue;
			if (!currentTrackedAssets.exists(key))
				destroyGraphic(FlxG.bitmap.get(key));
		}

		// clear all sounds that are cached
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = [];
		function checkForGraphics(spr:Dynamic)
		{
			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
				if(grp != null)
				{
					for (member in grp)
					{
						checkForGraphics(member);
					}
					return;
				}
			}

			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
				if(gfx != null)
				{
					protectedGfx.push(gfx);
				}
			}
		}

		for (key in FlxG.bitmap._cache.keys())
		{
			if(key.contains('sticker') || key.contains('transitionSwag') || key.contains('asbelin') || key.contains('stickers-set')) continue;
			var graphic:FlxGraphic = FlxG.bitmap._cache.get(key);
			if(graphic != null && !protectedGfx.contains(graphic))
			{
				destroyGraphic(graphic);
				FlxG.bitmap._cache.remove(key);
			}
		}
	}

	inline static function destroyGraphic(graphic:FlxGraphic)
	{
		if (graphic != null)
		{
			var bitmap:BitmapData = graphic.bitmap;
			if (bitmap != null && !bitmap.__isDisposed)
			{
				bitmap.disposeImage();
				bitmap.dispose();
			}
			graphic.bitmap = null;
			graphic.destroy();
		}
	}

	// ... resto del archivo igual al original (no modificado para brevedad, usa tu Paths base)
	static public var currentTrackedAssets:Map<String, FlxGraphic> = [];
	static public var currentTrackedSounds:Map<String, Sound> = [];
	static public var currentTrackedAtlas:Map<String, FlxAtlasFrames> = [];
	static public var currentTrackedFrames:Map<String, FlxFrame> = [];

	public static function getPath(file:String, type:AssetType, ?library:Null<String> = null, ?modsAllowed:Bool = false):String
	{
		#if MODS_ALLOWED
		if(modsAllowed)
		{
			var modded:String = modFolders(file);
			if(FileSystem.exists(modded))
				return modded;
		}
		#end

		if(library != null)
			return getLibraryPath(file, library);

		if (currentModDirectory != null && currentModDirectory.length > 0)
		{
			var modPath:String = mods(currentModDirectory + '/' + file);
			if (FileSystem.exists(modPath))
				return modPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library:String = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file) else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		return '$library:assets/$library/$file';
	}

	inline static function getPreloadPath(file:String)
	{
		return 'assets/$file';
	}

	inline public static function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline public static function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline public static function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline public static function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline public static function shaderFragment(key:String, ?library:String)
	{
		return getPath('shaders/$key.frag', TEXT, library, true);
	}

	inline public static function shaderVertex(key:String, ?library:String)
	{
		return getPath('shaders/$key.vert', TEXT, library, true);
	}

	inline public static function lua(key:String, ?library:String)
	{
		return getPath('$key.lua', TEXT, library, true);
	}

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	inline public static function sound(key:String, ?library:String):Sound
	{
		var sound:Sound = returnSound('sounds', key, library);
		return sound;
	}

	inline public static function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline public static function music(key:String, ?library:String):Sound
	{
		var file:Sound = returnSound('music', key, library);
		return file;
	}

	inline public static function image(key:String, ?library:String):Dynamic
	{
		var returnAsset:FlxGraphic = returnGraphic(key, library);
		return returnAsset;
	}

	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return File.getContent(modFolders(key));

		if (FileSystem.exists(mods(currentModDirectory + '/' + key)))
			return File.getContent(mods(currentModDirectory + '/' + key));

		if (FileSystem.exists(key))
			return File.getContent(key);
		#end

		if (FileSystem.exists(getPreloadPath(key)))
			return File.getContent(getPreloadPath(key));

		return Assets.getText(getPath(key, TEXT));
		#else
		return Assets.getText(getPath(key, TEXT));
		#end
	}

	inline static public function getAtlas(key:String, ?library:String, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var useMod = false;
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var myXml:Dynamic = getPath('images/$key.xml', TEXT, library, true);
		if(OpenFlAssets.exists(myXml, TEXT))
		{
			#if MODS_ALLOWED
			if(FileSystem.exists(myXml))
				useMod = true;
			#end

			return getSparrowAtlas(key, library, useMod);
		}

		#if MODS_ALLOWED
		var myJson:Dynamic = getPath('images/$key.json', TEXT, library, true);
		#else
		var myJson:Dynamic = getPath('images/$key.json', TEXT, library);
		#end

		if(OpenFlAssets.exists(myJson, TEXT))
		{
			#if MODS_ALLOWED
			if(FileSystem.exists(myJson))
				useMod = true;
			#end

			return getAsepriteAtlas(key, library, useMod);
		}
		return getPackerAtlas(key, library, useMod);
	}

	static public var currentModDirectory:String = '';
	static public var currentTrackedChars:Map<String, Character> = [];

	public static function mods(key:String)
	{
		return 'mods/' + key;
	}

	public static function modFolders(key:String)
	{
		if(currentModDirectory != null && currentModDirectory.length > 0)
		{
			var fileToCheck:String = mods(currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

		for(mod in Mods.getGlobalMods())
		{
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}
		return 'mods/' + key;
	}

	public static function modsJson(key:String)
	{
		return modFolders('data/' + key + '.json');
	}

	public static function modsVideo(key:String)
	{
		return modFolders('videos/' + key + '.' + VIDEO_EXT);
	}

	public static function modsSounds(path:String, key:String)
	{
		return modFolders(path + '/' + key + '.' + SOUND_EXT);
	}

	public static function modsImages(key:String)
	{
		return modFolders('images/' + key + '.png');
	}

	static public function getSparrowAtlas(key:String, ?library:String = null, ?modsAllowed:Bool = false):FlxAtlasFrames
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key, library, modsAllowed);
		var xmlExists:Bool = false;

		if(OpenFlAssets.exists(getPath('images/$key.xml', TEXT, library, modsAllowed), TEXT))
		{
			xmlExists = true;
		}

		return FlxAtlasFrames.fromSparrow((imageLoaded != null ? imageLoaded : image(key, library, modsAllowed)), (xmlExists ? File.getContent(getPath('images/$key.xml', TEXT, library, modsAllowed)) : getPath('images/$key.xml', TEXT, library, modsAllowed)));
		#else
		return FlxAtlasFrames.fromSparrow(image(key, library), getPath('images/$key.xml', TEXT, library));
		#end
	}

	static public function getAsepriteAtlas(key:String, ?library:String = null, ?modsAllowed:Bool = false):FlxAtlasFrames
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key, library, modsAllowed);
		var myJson:Dynamic = getPath('images/$key.json', TEXT, library, true);
		#else
		var myJson:Dynamic = getPath('images/$key.json', TEXT, library);
		#end

		return FlxAtlasFrames.fromTexturePackerJson((imageLoaded != null ? imageLoaded : image(key, library, modsAllowed)), (FileSystem.exists(myJson) ? File.getContent(myJson) : myJson));
	}

	static public function getPackerAtlas(key:String, ?library:String = null, ?modsAllowed:Bool = false):FlxAtlasFrames
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key, library, modsAllowed);
		var myPacker:Dynamic = getPath('images/$key.txt', TEXT, library, true);
		#else
		var myPacker:Dynamic = getPath('images/$key.txt', TEXT, library);
		#end

		return FlxAtlasFrames.fromSpriteSheetPacker((imageLoaded != null ? imageLoaded : image(key, library, modsAllowed)), (FileSystem.exists(myPacker) ? File.getContent(myPacker) : myPacker));
	}

	inline static public function getSparrowAtlasCustom(key:String, ?library:String = null):FlxAtlasFrames
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key, library, true);
		var xmlExists:Bool = false;
		if(OpenFlAssets.exists(getPath(key + '.xml', TEXT, library, true), TEXT))
		{
			xmlExists = true;
		}

		return FlxAtlasFrames.fromSparrow((imageLoaded != null ? imageLoaded : image(key, library, true)), (xmlExists ? File.getContent(getPath(key + '.xml', TEXT, library, true)) : getPath(key + '.xml', TEXT, library, true)));
		#else
		var imageLoaded:FlxGraphic = returnGraphic(key, library, true);
		return FlxAtlasFrames.fromSparrow(imageLoaded, getPath(key + '.xml', TEXT, library, true));
		#end
	}

	public static function returnGraphic(key:String, ?library:String, ?modsAllowed:Bool = false)
	{
		#if MODS_ALLOWED
		var modKey:String = modFolders('images/$key.png');
		if(FileSystem.exists(modKey))
		{
			if(!currentTrackedAssets.exists(modKey)) {
				var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(BitmapData.fromFile(modKey), false, modKey);
				newGraphic.persist = true;
				currentTrackedAssets.set(modKey, newGraphic);
			}
			localTrackedAssets.push(modKey);
			return currentTrackedAssets.get(modKey);
		}
		#end

		var path = getPath('images/$key.png', IMAGE, library, modsAllowed);
		if (OpenFlAssets.exists(path, IMAGE))
		{
			if(!currentTrackedAssets.exists(path))
			{
				var newGraphic:FlxGraphic = FlxGraphic.fromAssetKey(path, false, path, false);
				newGraphic.persist = true;
				currentTrackedAssets.set(path, newGraphic);
			}
			localTrackedAssets.push(path);
			return currentTrackedAssets.get(path);
		}
		return null;
	}

	public static function returnSound(path:String, key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var file:String = modsSounds(path, key);
		if(FileSystem.exists(file))
		{
			if(!currentTrackedSounds.exists(file))
			{
				currentTrackedSounds.set(file, Sound.fromFile(file));
			}
			localTrackedAssets.push(file);
			return currentTrackedSounds.get(file);
		}
		#end
		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
		gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
		if(!currentTrackedSounds.exists(gottenPath))
			#if MODS_ALLOWED
			currentTrackedSounds.set(gottenPath, Sound.fromFile('./' + gottenPath));
			#else
			{
				var retSound = OpenFlAssets.getSound(getPath('$path/$key.$SOUND_EXT', SOUND, library));
				currentTrackedSounds.set(gottenPath, retSound);
			}
			#end
		localTrackedAssets.push(gottenPath);
		return currentTrackedSounds.get(gottenPath);
	}
}
