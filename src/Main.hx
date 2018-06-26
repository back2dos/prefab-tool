package ;

import coconut.data.*;
import coconut.ui.*;
import tink.state.*;
import js.Browser.*;
using tink.CoreApi;

class Main {
  static function main() {
    new Root({}).mount(document.body);
  }
}

class Root extends View {
  @:state var prefabs:List<Prefab> = null;
  
  function add()
    prefabs = prefabs.append(new Prefab({ id: window.prompt("name") }));

  function render() '
    <div>
      <button onclick=${add}>
        Add prefab
      </button>
      <for ${p in prefabs}>
        <PrefabView data=${p} />
      </for>
    </div>
  ';
}

class Component implements Model {
  @:constant var def:ComponentDef;
  @:computed var id:String = def.id;
  @:computed var props:List<PropDef> = def.props;

  @:constant private var values:ObservableMap<String, Any> = new ObservableMap(new Map());

  public function keys():Array<String>
    return [for (p in def.props) p.id];

  public function has(name:String):Bool
    return getDef(name) != None;

  public function getDef(name:String)
    return props.first(p -> p.id == name);

  public function set(name:String, value:Any) {
    #if debug
    if (getDef(name) == None) 
      throw '${def.id} does not have property $name';
    #end
    values.set(name, value);
  }
  public function get(name:String):Any {
    var propDef = getDef(name);
    #if debug
    if (propDef) throw '${def.id} does not have property $name';
    #end
    return switch values.get(name) {
      case null: switch propDef {
        case Some(v): v.value;
        default: null;
      } 
      case v: v;
    }
  }
  static public var DEFS:List<ComponentDef> = [
    {id: "MoviePlayer", props: [{id:"symbolName", type:Text}, {id:"libraryName", type:Text}]},
    {id: "CollidableBoxMover", props: [{id:"updateEveryFrame", type:Flag, value: true}]},
    {id: "Gun", props: [{id:"time", type:Number}, {id:"interval", type:Number}]},
    {id: "DisplayComponent", props: []},
    {id: "Disposer", props: []},
    {id: "ShadowCaster", props: []},
    // {id: "CollidableBox", props: [{id:"bounds", type:"Rectangle", value:"0,0,100,100"}]},
  ];
}

class PrefabView extends View {
  @:attribute var data:Prefab;
  function getCurrent()
    return (cast toElement().getElementsByTagName('select')[0]:js.html.SelectElement).selectedIndex;
  function render() '
    <div class="prefab">
      <h2>${data.id}</h2>
      <switch ${data.getMissing()}>
        <case ${[]}>
        <case ${missing}>
          <form onsubmit=${{ event.preventDefault(); data.add(missing[getCurrent()].id); }}>
            <select>
              <for ${def in missing}>
                <option value=${def.id}>${def.id}</option>
              </for>
            </select>
            <button>Add Component</button>
          </form>
      </switch>
      <let components=${data.components.toArray()} total=${data.components.length}>
        <for ${i in 0...total}>
          <let comp=${components[i]}>
            <ComponentView 
              data=${comp} 
              index=${i} 
              up=${if (i > 0) data.move.bind(comp, -1) else null}
              down=${if (i < total - 1) data.move.bind(comp, 1) else null}
              delete=${data.remove(comp)}
            />
          </let>
        </for>
      </let>
    </div>
  ';
}

class ComponentView extends View {
  
  @:attribute var data:Component;
  @:attribute var up:Void->Void = null;
  @:attribute var down:Void->Void = null;
  @:attribute function delete():Void;
  @:attribute var index:Int;

  function render() '
    <div class="component">
      <h3><small>${index}</small>${data.id}</h3>
      
      <div class="buttons">
        <if ${up != null}>
          <button onclick={up}>↑</button>
        </if>
        
        <if ${down != null}>
          <button onclick={down}>↓</button>
        </if>
        <button onclick={delete}>×</button>
      </div>

      <table>
        <for ${p in data.props}>
          <tr>
            <td>${p.id}</td>
            <td>
              <switch ${p.type}>
                <case ${Number}>
                  <input type="number" value=${data.get(p.id)} onchange=${data.set(p.id, event.target.value)} />
                <case ${Flag}>
                  <input type="checkbox" checked=${data.get(p.id)} onchange=${data.set(p.id, event.target.checked)} />
                <case ${Text}>
                  <input type="text" value=${data.get(p.id)} onchange=${data.set(p.id, event.target.value)} />
              </switch>
            </td>
          </tr>
        </for>
      </table>
    </div>
  ';
}

typedef ComponentDef = {
  final id:String;
  final props:List<PropDef>;
}

typedef PropDef = {
  final id:String;
  final type:PropType;
  @:optional final value:Any;
}

enum PropType {
  Number;
  Flag;
  Text;
}

class Prefab implements Model {
  
  @:constant var id:String;
  @:observable var components:List<Component> = null;
  @:computed var length:Int = components.length;

  public function has(id:String)
    return components.exists(c -> c.id == id);

  public function iterator()
    return components.iterator();

  public function getMissing()
    return [for (def in Component.DEFS) if (!has(def.id)) def];

  @:transition function add(id:String) {
    return 
      if (has(id)) new Error(Conflict, 'Prefab $id alread has $id');
      else switch Component.DEFS.first(c -> c.id == id) {
        case None: new Error(NotFound, 'Unknown component $id');
        case Some(def): { components: components.append(new Component({ def: def })) };
      }
  }

  @:transition function remove(component:Component) 
    return { components: components.filter(c -> c != component) }

  @:transition function move(component:Component, by:Int) {
    var arr = components.toArray();
    return switch arr.indexOf(component) {
      case -1: new Error(NotFound, 'Prefab $id does not own ${component.id}');
      case _ + by => index: 
        if (index < 0) index = 0;
        else if (index >= arr.length) index = arr.length - 1;
        arr.remove(component);
        arr.insert(index, component);
        @patch { components: arr };
    }
  }

}