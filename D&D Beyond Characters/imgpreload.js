var themeID = null;
function checkForImgs(ss,base) {
    var imgs = [];
    for (var r=0;r<ss.length;r++) {
        if (ss[r].style && ss[r].style.backgroundImage) {
            var urlRE = /^url\(\"([^")]*)\"\)/;
            reRes = urlRE.exec(ss[r].style.backgroundImage);
            if (reRes && reRes[1]) {
                var url = new URL(reRes[1],base?base:document.location);
                if (url.searchParams.get("themeId")) {
                    themeID = url.searchParams.get("themeId");
                }
                imgs.push(url.href);
            }
        }
    }
    return(imgs);
}
function processSS(ss) {
    try {
        if(!ss.cssRules) return;
    } catch(e) {
        if(e.name !== 'SecurityError') throw e;
        return;
    }
    return checkForImgs(ss.cssRules,ss.href);
}

var allImages = [
                 "https://media-waterdeep.cursecdn.com/attachments/0/84/background_texture.png",
                 "https://media-waterdeep.cursecdn.com/attachments/1/614/builder1k.jpg",
                 "https://media-waterdeep.cursecdn.com/attachments/1/615/builder2k.jpg",
                 "https://media-waterdeep.cursecdn.com/attachments/1/616/builder4k.jpg",
                 "https://media.dndbeyond.com/mega-menu/9af3bf38a8f79012bcedea2aae247973.jpg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/advantage-icon.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/builder-icon-white.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/chevron-down-dark.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/chevron-down-disabled.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/chevron-down-grey.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/chevron-left-disabled.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/chevron-left-white.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/chevron-right-disabled.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/chevron-right-white.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/chevron-up-black.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/collapsible-480-bottom.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/collapsible-480-highlight.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/collapsible-480-hover-highlight.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/collapsible-480-hover.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/collapsible-480.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/collapsible-700-highlight.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/collapsible-700-hover-highlight.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/abilityscore.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/ac.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/attune-empty.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/attune.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/content-box-fancy-small-thin.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/content-box-fancy-tall-thin.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/content-box-small-thin.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/content-box-small.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/content-box-square-medium-thin.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/content-box-tall-thin.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/content-box-tall.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/eqp.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/initiative.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/inspiration.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/mobile-divider-edge.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/mobile-divider-repeat.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/saves-int-small.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/saves-int.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/senses-int-small.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/senses-int.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/sidebar-cap.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/skills-tablet.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/skills.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/speed.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/stats.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/content-frames/status.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/disadvantage-icon.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/expanded-listing-item-bottom-border-700.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/frames/Sylgar.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/frames/animated-eye.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/frames/animated-eye2.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/frames/mtof/blue-gem-2-gem.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/frames/mtof/cog-1.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/frames/mtof/cog-2.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/frames/mtof/orrery-planet-1.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/frames/mtof/orrery-planet-2.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/frames/mtof/orrery-ring.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/health-adjust-icon.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/help-active.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/help-inactive.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/align-left.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/align-right.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/filter-active.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/filter.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/fixed.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/grid-squares.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/inspiration.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/item-slot/body.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/item-slot/feet.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/item-slot/hands.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/item-slot/head.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/item-slot/holding.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/item-slot/jewelry.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/item-slot/person.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/item-slot/shoulders.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/item-slot/waist.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/item-slot/wrists.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/lock.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/overlay.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/pane-left-disabled.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/pane-left.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/pane-right-disabled.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/pane-right.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/sidebar-left.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/sidebar-right.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/spell-schools/abjuration.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/spell-schools/conjuration.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/spell-schools/divination.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/spell-schools/enchantment.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/spell-schools/evocation.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/spell-schools/illusion.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/spell-schools/necromancy.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/spell-schools/transmutation.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/icons/unlock.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/immunities-icon.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/loading-ring.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/print-icon-inactive.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/print-icon.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/proficiency-double-modified.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/proficiency-double.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/proficiency-half-modified.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/proficiency-half.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/proficiency-modified.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/proficiency.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/resistances-icon.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/savingthrow-negative-icon.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/savingthrow-positive-icon.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/section-group-header.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/sheet-active.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/sheet-filled-inactive.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/sheet-filled.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/sheet-inactive.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/vulnerabilities-icon.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/character-sheet/wheel-notch.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/characters/default-avatar-builder.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/ddb-borders-med.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/dnd-beyond-logo.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/errors/500.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/charisma.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/constitution.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/dexterity.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/intelligence.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/strength.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/white/charisma.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/white/constitution.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/white/dexterity.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/white/intelligence.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/white/strength.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/white/wisdom.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/abilities/wisdom.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/attack_types/general_spell.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/attack_types/melee_spell.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/attack_types/melee_weapon.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/attack_types/ranged_spell.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/attack_types/ranged_weapon.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/attack_types/thrown.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/attack_types/unarmedstrike-dark.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/attack_types/weapon-spell-damage.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/conditions/unconscious.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/conditions/white/unconscious.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/gear-grey.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/gear.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/healing-types/hp.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/homebrew.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/adventuresleague.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/backdrop.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/builders.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/dawn.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/downloadpdf.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/editcharacter.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/frame.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/leveldown.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/levelup.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/longrest.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/managelevel.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/managexp.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/portrait.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/preferences.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/share.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/shortrest.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/menu_items/theme.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/search-grey.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/x.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/icons/yes-no/check-green.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/listing-bars/1a-700-hover.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/listing-bars/1a-700.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/listing-bars/1a.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/logos/fng-small.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/mon-summary/paper-texture.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/mon-summary/stat-bar-book.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/mon-summary/stat-block-top-texture.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/spell-schools/35/abjuration.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/spell-schools/35/conjuration.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/spell-schools/35/divination.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/spell-schools/35/enchantment.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/spell-schools/35/evocation.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/spell-schools/35/illusion.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/spell-schools/35/necromancy.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/spell-schools/35/transmutation.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/sprites/charsheet-atlas-black.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/sprites/charsheet-atlas-builder.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/sprites/charsheet-atlas-red.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/sprites/charsheet-atlas-white.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/sprites/charsheet-atlas.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/sprites/currency-sprite.png",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/sprites/plus_minus-disabled.svg",
                 "https://www.dndbeyond.com/Content/Skins/Waterdeep/images/sprites/plus_minus-white.svg"
                 ];

var allSheets = document.styleSheets;
for (var ss=0; ss < allSheets.length; ss++) {
    var foundImgs = processSS(allSheets[ss]);
    var combinedArray = allImages.concat(foundImgs);
    allImages = combinedArray;
}

if (themeID) {
    var themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=icon-builder",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=icon-manage-level",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=icon-short-rest",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=icon-long-rest",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=icon-backdrop",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=icon-theme",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=icon-portrait",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=icon-preferences",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=icon-share",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=icon-export",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=mobile-divider-edge",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=mobile-divider-repeat",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=sidebar-cap",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=ability-score",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=small-stat",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=status",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=inspiration",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=inspiration-token",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=content-box-fancy-small",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=content-box-fancy-small-thin",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=content-box-square-medium",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=content-box-square-medium-thin",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=content-box-fancy-tall",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=content-box-fancy-tall-thin",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=content-box-tall",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=content-box-tall-thin",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=content-box-small",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=content-box-small-thin",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=initiative",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=ac",document.location);
    allImages.push(themeImg.href);
    themeImg = new URL("/api/character/svg/download?themeId=" + themeID + "&name=attune",document.location);
    allImages.push(themeImg.href);
}
var uniqueImgs = [];
$.each(allImages, function(i, el){
   if($.inArray(el, uniqueImgs) === -1 && el) {
       // These images always fail, remove them
       if (!el.toLowerCase().endsWith("/skins/images/markitup/menu.png") &&
           !el.toLowerCase().endsWith("/skins/images/markitup/submenu.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/ui/grippie.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/16x16/vanity-icon-staff.png") &&
           !el.toLowerCase().endsWith("/skins/blocks/images/icons/twitch/twitchlogo.png") &&
           !el.toLowerCase().endsWith("/skins/blocks/images/icons/twitch/glitch-white.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/logo.png") &&
           !el.toLowerCase().endsWith("/skins/global/images/ui/remove3.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/sourcepoint-logo.png") &&
           !el.toLowerCase().endsWith("/skins/blocks/images/icons/16x16/grey/icon-moderator-arrow-down.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/logo-home.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/responsive-login-logo.svg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/css/images/ui-icons_444444_256x240.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/css/images/ui-icons_555555_256x240.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/css/images/ui-icons_ffffff_256x240.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/css/images/ui-icons_777620_256x240.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/css/images/ui-icons_cc0000_256x240.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/css/images/ui-icons_777777_256x240.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/ui/ajax-loader-light.gif") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/classes/barbarian.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/classes/fighter.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/classes/monk.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/classes/rogue.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/item_types/artifact.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/sprites/plus_minus-spells.svg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/conditions/exhausted.svg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/classes/barbarian_icon@2x.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/classes/fighter_icon@2x.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/classes/monk_icon@2x.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/classes/rogue_icon@2x.png") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/aberration_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/beast_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/celestial_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/construct_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/dragon_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/elemental_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/fey_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/fiend_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/giant_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/humanoid_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/monstrosity_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/ooze_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/plant_icon.jpg") &&
           !el.toLowerCase().endsWith("/skins/waterdeep/images/icons/monsters/undead_icon.jpg")
           ) {
                uniqueImgs.push(el);
            }
       }
});
allImages = uniqueImgs;

$.each(allImages, function(i, el){
       var _linkTag = document.createElement("link");
       _linkTag.rel = "preload";
       _linkTag.href = el;
       _linkTag.as = "image";
       document.head.appendChild(_linkTag);
       });

var dataTarget = document.getElementById("character-tools-target");
if (dataTarget) {
    var resources = window.performance.getEntriesByType("resource");
    var resourceURLS = [];
    //resourceURLS.push("username=" + ddbuser + "&characterId=" + ddbchID + "&csrfToken=" + ddbtoken);
    resources.forEach(function (resource) {
                      resourceURLS.push(resource.name);
                      });
    var allRes = resourceURLS.concat(allImages);
    var uniqueRes = [];
    $.each(allRes, function(i, el){
           if($.inArray(el, uniqueRes) === -1 && el) {
                        uniqueRes.push(el);
            }
           });
    uniqueRes;
} else {
    [];
}

