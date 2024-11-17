package funkin.ui.debug.char.components.dialogs;

import funkin.ui.debug.char.pages.CharCreatorGameplayPage.CharDialogType;
import funkin.data.character.CharacterData.CharacterRenderType;
import haxe.ui.containers.dialogs.CollapsibleDialog;
import haxe.ui.data.ArrayDataSource;

@:build(haxe.ui.macros.ComponentMacros.build("assets/exclude/data/ui/char-creator/dialogs/anim-dialog.xml"))
class AddAnimDialog extends DefaultPageDialog
{
  public var linkedChar:CharCreatorCharacter = null;

  override public function new(daPage:CharCreatorGameplayPage, char:CharCreatorCharacter)
  {
    super(daPage);
    linkedChar = char;

    // dialog callback bs
    charAnimFrames.disabled = charAnimFlipX.disabled = charAnimFlipY.disabled = charAnimFramerate.disabled = (char.renderType == CharacterRenderType.AnimateAtlas);
    charAnimFrames.tooltip = charAnimFlipX.tooltip = charAnimFlipY.tooltip = charAnimFramerate.tooltip = (char.renderType == CharacterRenderType.AnimateAtlas ? "Unavailable for Atlas Characters." : null);

    charAnimFrameList.dataSource = new ArrayDataSource();
    if (char.renderType != CharacterRenderType.AnimateAtlas)
    {
      for (fname in char.frames.frames)
        if (fname != null) charAnimFrameList.dataSource.add({name: fname.name});
    }
    else
    {
      for (fname in char.atlasCharacter.listAnimations())
      {
        if (fname != null) charAnimFrameList.dataSource.add({name: fname});
      }
    }

    charAnimDropdown.onChange = function(_) {
      if (charAnimDropdown.selectedIndex == -1) // delele this shiz
      {
        charAnimName.text = charAnimFrames.text = "";
        charAnimLooped.selected = charAnimFlipX.selected = charAnimFlipY.selected = false;
        charAnimFramerate.pos = 24;
        charAnimOffsetX.pos = charAnimOffsetY.pos = 0;

        page.onDialogUpdate(this);
        return;
      }

      var animData = char.getAnimationData(charAnimDropdown.selectedItem.text);
      if (animData == null) return;

      charAnimName.text = animData.name;
      charAnimPrefix.text = animData.prefix;
      charAnimFrames.text = (animData.frameIndices != null && animData.frameIndices.length > 0 ? animData.frameIndices.join(", ") : "");

      charAnimLooped.selected = animData.looped ?? false;
      charAnimFlipX.selected = animData.flipX ?? false;
      charAnimFlipY.selected = animData.flipY ?? false;
      charAnimFramerate.pos = animData.frameRate ?? 24;

      charAnimOffsetX.pos = (animData.offsets != null && animData.offsets.length == 2 ? animData.offsets[0] : 0);
      charAnimOffsetY.pos = (animData.offsets != null && animData.offsets.length == 2 ? animData.offsets[1] : 0);

      char.playAnimation(charAnimName.text);
      page.onDialogUpdate(this);
    }

    charAnimSave.onClick = function(_) {
      if ((charAnimName.text ?? "") == "") return;
      if ((charAnimPrefix.text ?? "") == "") return;

      if (char.atlasCharacter != null && !char.atlasCharacter.hasAnimation(charAnimPrefix.text)) return;

      var indices = [];
      if (charAnimFrames.text != null && charAnimFrames.text != "")
      {
        var splitter = charAnimFrames.text.replace(" ", "").split(",");
        for (num in splitter)
          indices.push(Std.parseInt(num));
      }

      var shouldDoIndices:Bool = (indices.length > 0 && !indices.contains(null));
      var animAdded:Bool = char.addAnimation(charAnimName.text, charAnimPrefix.text, [charAnimOffsetX.pos, charAnimOffsetY.pos],
        (shouldDoIndices ? indices : []), Std.int(charAnimFramerate.pos), charAnimLooped.selected, charAnimFlipX.selected, charAnimFlipY.selected);

      if (!animAdded) return;

      if (linkedChar.generatedParams.importedCharacter == null)
      {
        daPage.ghostCharacter.addAnimation(charAnimName.text, charAnimPrefix.text, [charAnimOffsetX.pos, charAnimOffsetY.pos],
          (shouldDoIndices ? indices : []), Std.int(charAnimFramerate.pos), charAnimLooped.selected, charAnimFlipX.selected, charAnimFlipY.selected);
      }

      updateDropdown();
      charAnimDropdown.selectedIndex = charAnimDropdown.dataSource.size - 1;
    }

    charAnimDelete.onClick = function(_) {
      if ((charAnimName.text ?? "") == "") return;

      if (!char.removeAnimation(charAnimName.text)) return;
      if (linkedChar.generatedParams.importedCharacter == null) daPage.ghostCharacter.removeAnimation(charAnimName.text);

      updateDropdown();
      charAnimDropdown.selectedIndex = charAnimDropdown.dataSource.size - 1;

      if (charAnimDropdown.selectedIndex == -1) return;

      var anim:String = charAnimDropdown.value.text;
      char.playAnimation(anim);
      daPage.ghostCharacter.playAnimation(anim);
    }
  }

  public function updateDropdown()
  {
    charAnimDropdown.dataSource.clear();

    for (anim in linkedChar.animations)
      charAnimDropdown.dataSource.add({text: anim.name});

    var gameplayPage = cast(page, CharCreatorGameplayPage);
    if (gameplayPage.ghostId == "") gameplayPage.refreshGhoulAnims();
  }
}
