package funkin.ui.debug.char.components.dialogs;

import funkin.ui.debug.char.pages.CharCreatorGameplayPage.CharDialogType;
import haxe.ui.containers.dialogs.CollapsibleDialog;
import haxe.ui.data.ArrayDataSource;

@:build(haxe.ui.macros.ComponentMacros.build("assets/exclude/data/ui/char-creator/dialogs/anim-dialog.xml"))
class AddAnimDialog extends DefaultPageDialog
{
  public var linkedChar:CharCreatorCharacter = null;

  override public function new(daPage:CharCreatorDefaultPage, char:CharCreatorCharacter)
  {
    super(daPage);
    linkedChar = char;

    // dialog callback bs
    charAnimFrames.disabled = charAnimFlipX.disabled = charAnimFlipY.disabled = charAnimFramerate.disabled = (char.renderType == "atlas");
    charAnimFrames.tooltip = charAnimFlipX.tooltip = charAnimFlipY.tooltip = charAnimFramerate.tooltip = (char.renderType == "atlas" ? "Unavailable for Atlas Characters." : null);

    charAnimFrameList.dataSource = new ArrayDataSource();
    if (char.renderType != "atlas")
    {
      for (fname in char.frames.frames)
        if (fname != null) charAnimFrameList.dataSource.add({name: fname.name});
    }
    else
    {
      for (symbolName in char.atlasCharacter.anim.symbolDictionary.keys())
      {
        if (symbolName != null) charAnimFrameList.dataSource.add({name: symbolName});
      }
    }

    charAnimDropdown.onChange = function(_) {
      if (charAnimDropdown.selectedIndex == -1) // delele this shiz
      {
        charAnimName.text = charAnimFrames.text = "";
        charAnimLooped.selected = charAnimFlipX.selected = charAnimFlipY.selected = false;
        charAnimFramerate.pos = 24;
        charAnimOffsetX.pos = charAnimOffsetY.pos = 0;

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
      char.playAnimation(charAnimName.text);

      cast(page, CharCreatorGameplayPage).ghostCharacter.addAnimation(charAnimName.text, charAnimPrefix.text, [charAnimOffsetX.pos, charAnimOffsetY.pos],
        (shouldDoIndices ? indices : []), Std.int(charAnimFramerate.pos), charAnimLooped.selected, charAnimFlipX.selected, charAnimFlipY.selected);

      updateDropdown();
      charAnimDropdown.selectedIndex = charAnimDropdown.dataSource.size - 1;
    }
  }

  function updateDropdown()
  {
    charAnimDropdown.dataSource.clear();

    for (anim in linkedChar.animations)
      charAnimDropdown.dataSource.add({text: anim.name});

    var gameplayPage = cast(page, CharCreatorGameplayPage);
    if (gameplayPage.ghostId == "") gameplayPage.refreshGhoulAnims();
  }
}
