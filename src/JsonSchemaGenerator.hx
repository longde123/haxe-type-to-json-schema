#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.Tools;
using StringTools;

private typedef StructInfo = {
    name:String,
    doc:String,
}
#end

class JsonSchemaGenerator {
    public static macro function generate(type) {
        var schema = genSchema(Context.getType(type.toString()), type.pos, null);
        return macro $v{schema};
    }

    #if macro
    static function genSchema(type:Type, pos:Position, structInfo:Null<StructInfo>):JsonSchema {
        switch (type) {
            case TType(_.get() => dt, params):
                return switch [dt, params] {
                    case [{pack: [], name: "Null"}, [realT]]:
                        genSchema(realT, pos, null);
                    default:
                        genSchema(dt.type.applyTypeParameters(dt.params, params), dt.pos, {name: dt.name, doc: dt.doc});
                }

            case TInst(_.get() => cl, params):
                switch [cl, params] {
                    case [{pack: [], name: "String"}, []]:
                        return {type: "string"};
                    case [{pack: [], name: "Array"}, [elemType]]:
                        return {
                            type: "array",
                            items: genSchema(elemType, pos, null)
                        };
                    default:
                }

            case TAbstract(_.get() => ab, params):
                switch [ab, params] {
                    case [{pack: [], name: "Int"}, []]:
                        return {type: "integer"};
                    case [{pack: [], name: "Float"}, []]:
                        return {type: "number"};
                    case [{pack: [], name: "Bool"}, []]:
                        return {type: "boolean"};
                    default:
                }

            case TAnonymous(_.get() => anon):
                var props = new haxe.DynamicAccess();
                var required = [];

                // sort by declaration position
                anon.fields.sort(function(a, b) return a.pos.getInfos().min - b.pos.getInfos().min);

                for (i in 0...anon.fields.length) {
                    var f = anon.fields[i];
                    var schema = genSchema(f.type, f.pos, null);
                    schema.propertyOrder = i;
                    if (f.doc != null)
                        schema.description = f.doc.trim();
                    props[f.name] = schema;
                    if (!f.meta.has(":optional"))
                        required.push(f.name);
                }
                var schema:JsonSchema = {
                    type: "object",
                    properties: props,
                    additionalProperties: false,
                }
                if (required.length > 0)
                    schema.required = required;
                if (structInfo != null) {
                    if (structInfo.doc != null)
                        schema.description = structInfo.doc.trim();
                }
                return schema;

            default:
        }
        throw new Error("Cannot generate Json schema for type " + type.toString(), pos);
    }
    #end
}
