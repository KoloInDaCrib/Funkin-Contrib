package funkin.data.character.migrator;

import funkin.data.character.CharacterData;
import funkin.data.character.CharacterRegistry;
import funkin.data.animation.AnimationData;

class CharacterDataMigrator
{
  public static inline function migrate(input:CharacterData_v1_0_0.CharacterData_v1_0_0):CharacterData
  {
    return migrate_CharacterData_v1_0_0(input);
  }

  public static function migrate_CharacterData_v1_0_0(input:CharacterData_v1_0_0.CharacterData_v1_0_0):CharacterData
  {
    return {
      version: CharacterRegistry.CHARACTER_DATA_VERSION,
      name: input.name,
      renderType: input.renderType,
      assetPaths: [input.assetPath],
      scale: input.scale,
      healthIcon: input.healthIcon,
      death: input.death,
      offsets: input.offsets,
      cameraOffsets: input.cameraOffsets,
      isPixel: input.isPixel,
      danceEvery: input.danceEvery,
      singTime: input.singTime,
      animations: migrate_AnimationData_v1_0_0(input.animations),
      startingAnimation: input.startingAnimation,
      flipX: input.flipX,
    };
  }

  static function migrate_AnimationData_v1_0_0(input:Array<CharacterData_v1_0_0.AnimationData_v1_0_0>):Array<AnimationData>
  {
    var animations:Array<AnimationData> = [];
    for (animation in input)
    {
      // no more assetPath
      animations.push(
        {
          prefix: animation.prefix,
          offsets: animation.offsets,
          looped: animation.looped,
          flipX: animation.flipX,
          flipY: animation.flipY,
          frameRate: animation.frameRate,
          frameIndices: animation.frameIndices,
          name: animation.name
        });
    }
    return animations;
  }
}
