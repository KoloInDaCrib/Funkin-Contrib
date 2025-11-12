package funkin.util.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type.AbstractType;
import haxe.macro.Type.DefType;
import haxe.macro.Type.ClassType;

/**
 * Macros to generate lists of classes at compile time.
 *
 * This code is a bitch glad Jason figured it out.
 * Based on code from CompileTime: https://github.com/jasononeil/compiletime
 */
@:nullSafety
class ClassMacro
{
  /**
   * Gets a list of `Class<T>` for all classes in a specified package.
   *
   * Example: `var list:Array<Class<Dynamic>> = listClassesInPackage("funkin", true);`
   *
   * @param targetPackage A String containing the package name to query.
   * @param includeSubPackages Whether to include classes located in sub-packages of the target package.
   * @return A list of classes matching the specified criteria.
   */
  public static macro function listClassesInPackage(targetPackage:String, includeSubPackages:Bool = true):ExprOf<Iterable<Class<Dynamic>>>
  {
    if (!onGenerateCallbackRegistered)
    {
      onGenerateCallbackRegistered = true;
      Context.onGenerate(onGenerate);
    }

    var request:String = 'package~${targetPackage}~${includeSubPackages ? "recursive" : "nonrecursive"}';

    classListsToGenerate.push(request);

    return macro funkin.util.macro.CompiledClassList.get($v{request});
  }

  /**
   * Get a list of `Class<T>` for all classes extending a specified class.
   *
   * Example: `var list:Array<Class<FlxSprite>> = listSubclassesOf(FlxSprite);`
   *
   * @param targetClass The class to query for subclasses.
   * @return A list of classes matching the specified criteria.
   */
  public static macro function listSubclassesOf<T>(targetClassExpr:ExprOf<Class<T>>):ExprOf<List<Class<T>>>
  {
    if (!onGenerateCallbackRegistered)
    {
      onGenerateCallbackRegistered = true;
      Context.onGenerate(onGenerate);
    }

    var targetClass:ClassType = MacroUtil.getClassTypeFromExpr(targetClassExpr);
    var targetClassPath:String = null;
    if (targetClass != null) targetClassPath = targetClass.pack.join('.') + '.' + targetClass.name;

    var request:String = 'extend~${targetClassPath}';

    classListsToGenerate.push(request);

    return macro funkin.util.macro.CompiledClassList.getTyped($v{request}, ${targetClassExpr});
  }

  /**
   * Get a list of Typedefs that redirect to classes such as `FlxSpriteGroup`, along with the classes they redirect to.
   */
  public static macro function listTypedefWrappers():ExprOf<Map<String, String>>
  {
    if (!onGenerateCallbackRegistered)
    {
      onGenerateCallbackRegistered = true;
      Context.onGenerate(onGenerate);
    }

    return macro funkin.util.macro.CompiledClassList.getTypedefWrappers();
  }

  #if macro
  /**
   * Callback executed after the typing phase but before the generation phase.
   * Receives a list of `haxe.macro.Type` for all types in the program.
   *
   * Only metadata can be modified at this time, which makes it a BITCH to access the data at runtime.
   */
  static function onGenerate(allTypes:Array<haxe.macro.Type>)
  {
    // Reset these, since onGenerate persists across multiple builds.
    classListsRaw = [];
    typedefList.clear();

    for (request in classListsToGenerate)
    {
      classListsRaw.set(request, []);
    }

    for (type in allTypes)
    {
      switch (type)
      {
        // Class instances
        case TInst(t, _params):
          var classType:ClassType = t.get();
          var className:String = t.toString();

          if (classType.isInterface)
          {
            // Ignore interfaces.
          }
          else
          {
            for (request in classListsToGenerate)
            {
              if (doesClassMatchRequest(classType, request))
              {
                classListsRaw.get(request).push(className);
              }
            }
          }

        case TType(t1, _params):
          var defType:DefType = t1.get();
          var className:String = "";

          switch (defType.type)
          {
            case TInst(t2, _):
              className = t2.toString();

            case TAbstract(t2, params):
              var absType:AbstractType = t2.get();

              // See if the abstract has any implicit casts that we can use for the wrapper class.
              for (to in absType.to)
              {
                if (to.field == null) continue;

                switch (to.field.type)
                {
                  case TFun(args, ret):
                    // If there are no args, assume this is the only implicit cast.
                    if (args.length == 0)
                    {
                      switch (ret)
                      {
                        case TInst(t3, _):
                          className = t3.toString();

                        default:
                          // Do nothing.
                      }
                      break;
                    }

                    switch (args[0].t)
                    {
                      case TInst(_, checkParams):
                        // If the params match, use this instance.
                        var paramsMatch:Bool = (params.length == checkParams.length);
                        if (paramsMatch)
                        {
                          for (i in 0...params.length)
                          {
                            if (Std.string(params[i]) != Std.string(checkParams[i]))
                            {
                              paramsMatch = false;
                              break;
                            }
                          }
                        }

                        if (!paramsMatch) continue;

                        switch (ret)
                        {
                          case TInst(t3, _):
                            className = t3.toString();

                          default:
                        }
                        break;

                      default:
                        // Do nothing.
                    }

                  default:
                    // Do nothing.
                }
              }

              // Otherwise resort to using the impl class.
              if (className == "") className = absType.impl?.toString() ?? "";

            default:
              // Do nothing.
          }

          if (className == "") continue; // The class is an anonymous object; skip.

          var classKey:String = defType.pack.join(".") + (defType.pack.length > 0 ? "." : "") + defType.name;
          typedefList.set(classKey, className);

        // Other types (things like enums)
        default:
          continue;
      }
    }

    compileClassLists();
  }

  /**
   * At this stage in the program, `classListsRaw` is generated, but only accessible by macros.
   * To make it accessible at runtime, we must:
   * - Convert the String names to actual `Class<T>` instances, and store it as `classLists`
   * - Insert the `classLists` into the metadata of the `CompiledClassList` class.
   * `CompiledClassList` then extracts the metadata and stores it where it can be accessed at runtime.
   */
  static function compileClassLists()
  {
    var compiledClassList:ClassType = MacroUtil.getClassType("funkin.util.macro.CompiledClassList");

    if (compiledClassList == null) throw "Could not find CompiledClassList class.";

    // Reset outdated metadata.
    if (compiledClassList.meta.has('classLists')) compiledClassList.meta.remove('classLists');
    if (compiledClassList.meta.has('typedefList')) compiledClassList.meta.remove('typedefList');

    var classLists:Array<Expr> = [];
    // Generate classLists.
    for (request in classListsToGenerate)
    {
      // Expression contains String, [Class<T>...]
      var classListEntries:Array<Expr> = [macro $v{request}];
      for (i in classListsRaw.get(request))
      {
        // TODO: Boost performance by making this an Array<Class<T>> instead of an Array<String>
        // How to perform perform macro reificiation to types given a name?
        classListEntries.push(macro $v{i});
      }

      classLists.push(macro $a{classListEntries});
    }

    // Generate typedef wrappers. They're structured like [wrapperName, wrapperClass].
    var typedefWrappers:Array<Expr> = [];
    for (name => cls in typedefList)
    {
      var entry:Array<Expr> = [macro $v{name}, macro $v{cls}];
      typedefWrappers.push(macro $a{entry});
    }

    // Insert classLists into metadata.
    compiledClassList.meta.add('classLists', classLists, Context.currentPos());
    compiledClassList.meta.add('typedefList', typedefWrappers, Context.currentPos());
  }

  static function doesClassMatchRequest(classType:ClassType, request:String):Bool
  {
    var splitRequest:Array<String> = request.split('~');

    var requestType:String = splitRequest[0];

    switch (requestType)
    {
      case 'package':
        var targetPackage:String = splitRequest[1];
        var recursive:Bool = splitRequest[2] == 'recursive';

        var classPackage:String = classType.pack.join('.');

        if (recursive)
        {
          return StringTools.startsWith(classPackage, targetPackage);
        }
        else
        {
          var regex:EReg = ~/^${targetPackage}(\.|$)/;
          return regex.match(classPackage);
        }
      case 'extend':
        var targetClassName:String = splitRequest[1];

        var targetClassType:ClassType = MacroUtil.getClassType(targetClassName);

        if (MacroUtil.implementsInterface(classType, targetClassType))
        {
          return true;
        }
        else if (MacroUtil.isSubclassOf(classType, targetClassType))
        {
          return true;
        }

        return false;

      default:
        throw 'Unknown request type: ${requestType}';
    }
  }

  static var onGenerateCallbackRegistered:Bool = false;

  static var classListsRaw:Map<String, Array<String>> = [];
  static var classListsToGenerate:Array<String> = [];
  static var typedefList:Map<String, String> = [];
  #end
}
