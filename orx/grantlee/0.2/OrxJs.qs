var buffer = '';

function append() {
    for (var i = 0; i < arguments.length; i++) {
        if (arguments[i] !== undefined) {
            buffer += arguments[i] + '\n';
        }
    }
    if (arguments.length == 0) {
        buffer += '\n';
    }
}

function friendlyName(name) {
    name = name.replace(/[^a-z0-9]/gi, ' ');        // Keep alpha-numeric
    name = name[0].toUpperCase() + name.slice(1); // Proper case
    return name;
}

function getId(name) {
    // 'big enemy/hard-boss/boss_01' -> ['big', 'enemy', 'hard', 'boss', 'boss', '01']
    var parts = name.split(/\/|_|-| /g);
    
    for (var i = 0; i < parts.length; i++) {
        parts[i] = friendlyName(parts[i]);
    }
    
    // Optimize any sequences of the same identifier.
    // E.g. ['Boss', 'Boss', 'Boss'] -> 'Boss'
    var clean = parts[0];
    for (var i = 1; i < parts.length; i++) {
        if (parts[i] !== parts[i - 1]) {
            clean += parts[i];
        }
    }
    
    // Now we have an identifier suitable for .ini files.
    // E.g. 'BigEnemyHardBoss01'
    
    return clean;
}

function section(id) {
    return '[' + id + ']';
}

function frameSection(root, sprite, id, parentId) {
    var frameId = id;
    if (parentId !== undefined) {
        frameId += '@' + parentId;
    }
    result = section(frameId);

    if (root.exporterProperties.includeComments) {
        result += ' ; Source: ' + sprite.fullName;
    }
    
    return result;
}

function tagIf(key, value, condition) {
    if (condition) {
        return tag(key, value);
    }
}

function tag(key, value) {
    var maxTagLength = 13; // I.e. TextureOrigin
    while (key.length < maxTagLength) {
        key += ' ';
    }
    return key + ' = ' + value;
}

function pointToString(point) {
    return '(' + point.x + ', ' + point.y + ')';
}

function sortByName(arr) {
    return arr.slice().sort(function(a, b) {
        return a.trimmedName.localeCompare(b.trimmedName);
    });
}

function normPointToString(point) {
    if (point.x == 0.5 && point.y == 0.5)
        return 'center';
    if (point.x == 0.0 && point.y == 0.0)
        return 'top|left';
    if (point.x == 1.0 && point.y == 1.0)
        return 'bottom|right';
    if (point.x == 1.0 && point.y == 0.0)
        return 'top|right';
    if (point.x == 0.0 && point.y == 1.0)
        return 'bottom|left';
  
    return pointToString(point);
}

function sizeToString(size) {
    return '(' + size.width + ', ' + size.height + ')';
}

function printAnimation(root, sprite, texture, frameCount) {
    if (!root.settings.autodetectAnimations || frameCount < 2) {
        return;
    }
    
    var animationSetid = getContainerId(sprite.trimmedName, 'animation-set');
    var animId = getContainerId(sprite.trimmedName, 'anim');
    
    append(section(animationSetid),
           tag('Texture', texture.fullName),
           tagIf('KeepInCache', true, root.exporterProperties.keepInCache),
           tag('FrameSize', sizeToString(sprite.untrimmedSize)),
           tag('KeyDuration', root.exporterProperties.keyDuration),
           tag('Digits', digitCount(frameCount)),
           tag('StartAnim', animId),
           tag(animId, frameCount));
    
    append();
}

function printFrame(root, sprite, id, parentId) {
    append(frameSection(root, sprite, id, parentId),
           tag('TextureOrigin', pointToString(sprite.frameRect)),
           tag('TextureSize', sizeToString(sprite.frameRect)));

    if (root.settings.writePivotPoints) {
        append(tag('Pivot', normPointToString(sprite.pivotPointNorm)));
    }
    append();
}

function pad(num, size) {
    return ('000000000' + num).substr(-size);
}

function digitCount(num) {
    return num.toString().length;
}

function getFrameInfo(root, sprite, texture, frameData) {
    var name = sprite.trimmedName;
    var parentId;
    
    if (root.settings.autodetectAnimations && frameData.frameCount > 1) {
        var size = digitCount(frameData.frameCount);
        var anim = 'anim' + pad(frameData.frameNo, size);

        name = getContainerId(name, anim);
    } else {
        parentId = getId(texture.trimmedName);
    }
    
    return {
        id: getId(name),
        parentId: parentId
    };
}

function getContainerId(name, suffix) {
    name = name.replace(/\d+$/gi, suffix);
    
    return getId(name);
}

function getPath(name) {
    return name.replace(/\/[^\/]+$/g, '');
}

function sizeEqual(a, b) {
    if (a === undefined || b === undefined) {
        return false;
    }
    
    return a.width == b.width && a.height == b.height;
}

function isNewFrameSet(sprite, prevSprite) {
    if (prevSprite === undefined) {
        return true;
    }
    var path = getPath(sprite.trimmedName);
    var size = sprite.untrimmedSize;
    var prevPath = getPath(prevSprite.trimmedName);
    var prevSize = prevSprite.untrimmedSize;
    
    return (path !== prevPath || !sizeEqual(size, prevSize));
}

function getFrameData(root, sprites) {
    var results = [];
    
    var start = 0, current = 0;
    var prevSprite;
    
    for (var i = 0; i < sprites.length; i++) {
        var sprite = sprites[i];
        if (isNewFrameSet(sprite, prevSprite)) {
            start = i;
            current = 0;
            prevSprite = sprite;
        }
        
        results.push({
            frameNo: ++current
        });
    
        for (var j = start; j <= i; j++) {
            results[j].frameCount = current;
        }
    }
    
    return results;
}

function printFrames(root) {
    var textures = root.allResults[root.variantIndex].textures;
        
    for (var i = 0; i < textures.length; i++) {
        var texture = textures[i];
        var sprites = sortByName(texture.sprites);
        
        var frameData = getFrameData(root, sprites);
        
        for (var j = 0; j < sprites.length; j++) {
            // Only generate animation set for the first frame!
            if (frameData[j].frameNo == 1) {
                var sprite = sprites[j];
                printAnimation(root, sprite, texture, frameData[j].frameCount);
            }    
        }
        
        for (var j = 0; j < sprites.length; j++) {
            var sprite = sprites[j];
            var info = getFrameInfo(root, sprite, texture, frameData[j]);
            
            printFrame(root, sprite, info.id, info.parentId);
        }
    }
}

function printTexture(root, texture) {
    var id = getId(texture.trimmedName);
    append(section(id),
           tag('Texture', texture.fullName),
           tag('TextureSize', sizeToString(texture.size)),
           tagIf('KeepInCache', true, root.exporterProperties.keepInCache));
    
    append();
}

function printTextures(root) {
    var textures = root.allResults[root.variantIndex].textures;
    
    for (var i = 0; i < textures.length; i++) {
        printTexture(root, textures[i]);
    }
}

var ExportData = function(root) {
    buffer = '';
    
    printTextures(root);
    printFrames(root);
    
    return buffer;
}

ExportData.filterName = 'exportData';
Library.addFilter('ExportData');
