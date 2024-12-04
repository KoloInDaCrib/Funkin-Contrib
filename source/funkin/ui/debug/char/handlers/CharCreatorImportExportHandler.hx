package funkin.ui.debug.char.handlers;

import haxe.io.Path;
import funkin.data.character.CharacterRegistry;
import funkin.ui.debug.char.components.dialogs.freeplay.FreeplayDJSettingsDialog;
import funkin.ui.debug.char.components.dialogs.results.ResultsAnimDialog;
import funkin.ui.debug.char.pages.CharCreatorGameplayPage;
import funkin.ui.debug.char.pages.CharCreatorSelectPage;
import funkin.ui.debug.char.pages.CharCreatorFreeplayPage;
import funkin.ui.debug.char.pages.CharCreatorResultsPage;
import funkin.ui.debug.char.CharCreatorState;
import funkin.data.freeplay.player.PlayerData;
import funkin.data.freeplay.style.FreeplayStyleData;
import funkin.play.scoring.Scoring.ScoringRank;
import funkin.util.FileUtil;

using StringTools;

@:access(funkin.ui.debug.char.CharCreatorState)
@:access(funkin.ui.debug.char.pages.CharCreatorSelectPage)
@:access(funkin.ui.debug.char.pages.CharCreatorFreeplayPage)
class CharCreatorImportExportHandler
{
  public static function importCharacter(state:CharCreatorState, charId:String):Void
  {
    var gameplayPage:CharCreatorGameplayPage = cast state.pages[Gameplay];

    var data = CharacterRegistry.fetchCharacterData(charId);

    if (data == null)
    {
      trace('No character data for $charId (CharCreatorImportExportHandler.importCharacter)');
      return;
    }

    gameplayPage.currentCharacter.fromCharacterData(CharacterRegistry.fetchCharacterData(charId));
  }

  public static function exportAll(state:CharCreatorState)
  {
    var zipEntries = [];
    if (state.params.generateCharacter) exportCharacter(state, zipEntries);
    if (state.params.generatePlayerData) exportPlayableCharacter(state, zipEntries);

    FileUtil.saveFilesAsZIP(zipEntries);
  }

  public static function exportCharacter(state:CharCreatorState, zipEntries:Array<haxe.zip.Entry>):Void
  {
    var gameplayPage:CharCreatorGameplayPage = cast state.pages[Gameplay];

    if (gameplayPage.currentCharacter.renderType != funkin.data.character.CharacterData.CharacterRenderType.AnimateAtlas)
    {
      for (file in gameplayPage.currentCharacter.files)
      {
        // skip if the file is in a character path
        if (CharCreatorUtil.isPathProvided(file.name, "images/characters"))
        {
          continue;
        }

        zipEntries.push(FileUtil.makeZIPEntryFromBytes('images/characters/${Path.withoutDirectory(file.name)}', file.bytes));
      }
    }
    else
    {
      // no check needed there's no zip files in assets folder

      if (gameplayPage.currentCharacter.files.length > 0)
      {
        for (file in FileUtil.readZIPFromBytes(gameplayPage.currentCharacter.files[0].bytes))
        {
          var zipName = gameplayPage.currentCharacter.files[0].name.replace(".zip", "");

          zipEntries.push(FileUtil.makeZIPEntryFromBytes('images/characters/${Path.withoutDirectory(zipName)}/${Path.withoutDirectory(file.fileName)}',
            file.data));
        }
      }
    }

    // if the icon path isn't absolute, in the proper folder AND there already was an xml file (if we added one), then we don't save files and replace the typedef's id field
    if (gameplayPage.currentCharacter.healthIconFiles.length > 0)
    {
      var iconPath = gameplayPage.currentCharacter.healthIconFiles[0].name;
      if (CharCreatorUtil.isPathProvided(iconPath, "images/icons/icon-")
        && ((gameplayPage.currentCharacter.healthIconFiles.length > 1
          && CharCreatorUtil.isPathProvided(iconPath.replace(".png", ".xml"), "images/icons/icon-"))
          || gameplayPage.currentCharacter.healthIconFiles.length == 1))
      {
        var typicalPath = Path.withoutDirectory(iconPath).split(".")[0];
        gameplayPage.currentCharacter.healthIcon.id = typicalPath.replace("icon-", "");
      }
      else
      {
        for (file in gameplayPage.currentCharacter.healthIconFiles)
          zipEntries.push(FileUtil.makeZIPEntryFromBytes('images/icons/icon-${gameplayPage.currentCharacter.characterId}.${Path.extension(file.name)}',
            file.bytes));
      }
    }

    // we push this later in case we use a pre-existing icon
    zipEntries.push(FileUtil.makeZIPEntry('${gameplayPage.currentCharacter.characterId}.json', gameplayPage.currentCharacter.toJSON()));
  }

  public static function exportPlayableCharacter(state:CharCreatorState, zipEntries:Array<haxe.zip.Entry>):Void
  {
    var selectPage:CharCreatorSelectPage = cast state.pages[CharacterSelect];
    var freeplayPage:CharCreatorFreeplayPage = cast state.pages[Freeplay];
    var resultPage:CharCreatorResultsPage = cast state.pages[ResultScreen];

    var charID = selectPage.data.importedCharacter ?? selectPage.data.characterID;

    if (selectPage.data.charSelectFile != null)
    {
      var charSelectZipName = Path.withoutDirectory(selectPage.data.charSelectFile.name.replace(".zip", ""));
      for (file in FileUtil.readZIPFromBytes(selectPage.data.charSelectFile.bytes))
      {
        zipEntries.push(FileUtil.makeZIPEntryFromBytes('images/charSelect/${charSelectZipName}/${Path.withoutDirectory(file.fileName)}', file.data));
      }
    }

    var freeplayDJZipName = Path.withoutDirectory(freeplayPage.loadedSprFreeplayPath);
    if (freeplayPage.data.freeplayFile != null)
    {
      freeplayDJZipName = Path.withoutDirectory(freeplayPage.data.freeplayFile.name.replace(".zip", ""));
      for (file in FileUtil.readZIPFromBytes(freeplayPage.data.freeplayFile.bytes))
      {
        zipEntries.push(FileUtil.makeZIPEntryFromBytes('images/freeplay/${freeplayDJZipName}/${Path.withoutDirectory(file.fileName)}', file.data));
      }
    }

    var playerData:PlayerData = new PlayerData();
    playerData.name = "Unknown";
    playerData.ownedChars = selectPage.ownedCharacters;
    playerData.showUnownedChars = false;
    playerData.freeplayStyle = freeplayPage.useStyle ?? charID;

    @:privateAccess
    {
      playerData.freeplayDJ = new PlayerFreeplayDJData();
      playerData.freeplayDJ.assetPath = "freeplay/" + freeplayDJZipName;
      playerData.freeplayDJ.text1 = freeplayPage.bgText1;
      playerData.freeplayDJ.text2 = freeplayPage.bgText2;
      playerData.freeplayDJ.text3 = freeplayPage.bgText3;
      playerData.freeplayDJ.animations = freeplayPage.djAnims.copy();

      var pageDialog:FreeplayDJSettingsDialog = cast freeplayPage.dialogMap[FreeplayDJSettings];

      // this code gives me an eyesore
      playerData.freeplayDJ.fistPump =
        {
          introStartFrame: Std.int(pageDialog.introStartFrame.pos),
          introEndFrame: Std.int(pageDialog.introEndFrame.pos),
          loopStartFrame: Std.int(pageDialog.loopStartFrame.pos),
          loopEndFrame: Std.int(pageDialog.loopEndFrame.pos),
          introBadStartFrame: Std.int(pageDialog.introBadStartFrame.pos),
          introBadEndFrame: Std.int(pageDialog.introBadEndFrame.pos),
          loopBadStartFrame: Std.int(pageDialog.loopBadStartFrame.pos),
          loopBadEndFrame: Std.int(pageDialog.loopBadEndFrame.pos)
        }

      playerData.freeplayDJ.charSelect =
        {
          transitionDelay: pageDialog.charSelectTransitionDelay.pos
        }

      playerData.freeplayDJ.cartoon =
        {
          soundClickFrame: Std.int(pageDialog.soundClickFrame.pos),
          soundCartoonFrame: Std.int(pageDialog.soundCartoonFrame.pos),
          loopBlinkFrame: Std.int(pageDialog.loopBlinkFrame.pos),
          loopFrame: Std.int(pageDialog.loopFrame.pos),
          channelChangeFrame: Std.int(pageDialog.channelChangeFrame.pos)
        }
    }

    var resultPageDialog:ResultsAnimDialog = cast resultPage.dialogMap[RankAnims];

    playerData.charSelect = new PlayerCharSelectData(selectPage.position);
    playerData.results =
      {
        music: null,
        perfectGold: resultPageDialog.rankAnimationDataMap[PERFECT_GOLD],
        perfect: resultPageDialog.rankAnimationDataMap[PERFECT],
        excellent: resultPageDialog.rankAnimationDataMap[EXCELLENT],
        great: resultPageDialog.rankAnimationDataMap[GREAT],
        good: resultPageDialog.rankAnimationDataMap[GOOD],
        loss: resultPageDialog.rankAnimationDataMap[SHIT],
      };

    playerData.unlocked = true;

    zipEntries.push(FileUtil.makeZIPEntry('data/players/${charID}.json', playerData.serialize()));
    if (selectPage.nametagFile != null) zipEntries.push(FileUtil.makeZIPEntryFromBytes('images/charSelect${charID}Nametag.png', selectPage.nametagFile.bytes));

    if (freeplayPage.useStyle == null)
    {
      zipEntries.push(FileUtil.makeZIPEntry('data/ui/styles/${charID}.json',
        new json2object.JsonWriter<FreeplayStyleData>().write(freeplayPage.customStyleData, '  ')));

      for (file in freeplayPage.styleFiles)
        zipEntries.push(FileUtil.makeZIPEntryFromBytes('images/${file.name}', file.bytes));
    }
  }
}
