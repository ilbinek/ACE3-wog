#include "..\script_component.hpp"
/*
 * Author: Glowbal, ViperMaul
 * Unloads an object from a vehicle.
 *
 * Arguments:
 * 0: Item to be unloaded <STRING> or <OBJECT> (default: "")
 * 1: Holder object (vehicle) <OBJECT> (default: objNull)
 * 2: Unloader <OBJECT> (default: objNull)
 *
 * Return Value:
 * Object unloaded <BOOL>
 *
 * Example:
 * ["ACE_Wheel", cursorObject] call ace_cargo_fnc_unloadItem
 *
 * Public: Yes
 */

params [["_item", "", [objNull, ""]], ["_vehicle", objNull, [objNull]], ["_unloader", objNull, [objNull]]];
TRACE_3("params",_item,_vehicle,_unloader);

// Get config sensitive case name
if (_item isEqualType "") then {
    _item = _item call EFUNC(common,getConfigName);
};

// Check if item is actually part of cargo
private _loaded = _vehicle getVariable [QGVAR(loaded), []];

if !(_item in _loaded) exitWith {
    ERROR_3("Tried to unload item [%1] not in vehicle[%2] cargo[%3]",_item,_vehicle,_loaded);

    false // return
};

// Check if item can be unloaded
private _itemSize = _item call FUNC(getSizeItem);

if (_itemSize < 0) exitWith {
    false // return
};

// This covers testing vehicle stability and finding a safe position
private _emptyPosAGL = [_vehicle, _item, _unloader] call EFUNC(common,findUnloadPosition);
TRACE_1("findUnloadPosition",_emptyPosAGL);

if (_emptyPosAGL isEqualTo []) exitWith {
    // Display text saying there are no safe places to exit the vehicle
    if (!isNull _unloader && {_unloader == ACE_player}) then {
        [ELSTRING(common,NoRoomToUnload)] call EFUNC(common,displayTextStructured);
    };

    false // return
};

// Unload item from cargo
_loaded deleteAt (_loaded find _item);
_vehicle setVariable [QGVAR(loaded), _loaded, true];

// Update cargo space remaining
private _cargoSpace = _vehicle call FUNC(getCargoSpaceLeft);
_vehicle setVariable [QGVAR(space), _cargoSpace + _itemSize, true];

private _object = _item;

if (_object isEqualType objNull) then {
    detach _object;

    // hideObjectGlobal must be executed before setPos to ensure light objects are rendered correctly
    // Do both on server to ensure they are executed in the correct order
    [QGVAR(serverUnload), [_object, _emptyPosAGL]] call CBA_fnc_serverEvent;

    if (["ace_zeus"] call EFUNC(common,isModLoaded)) then {
        // Get which curators had this object as editable
        private _objectCurators = _object getVariable [QGVAR(objectCurators), []];

        if (_objectCurators isEqualTo []) exitWith {};

        [QEGVAR(zeus,addObjects), [[_object], _objectCurators]] call CBA_fnc_serverEvent;
    };
} else {
    _object = createVehicle [_item, _emptyPosAGL, [], 0, "NONE"];
    _object setPosASL (AGLtoASL _emptyPosAGL);

    [QEGVAR(common,fixCollision), _object] call CBA_fnc_localEvent;
    [QEGVAR(common,fixPosition), _object] call CBA_fnc_localEvent;
};

// Dragging integration
[_unloader, _object] call FUNC(unloadCarryItem);

// Invoke listenable event
["ace_cargoUnloaded", [_object, _vehicle, "unload"]] call CBA_fnc_globalEvent;

true // return
