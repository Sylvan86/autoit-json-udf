## Introduction
JSON is a pure data exchange format. Basically you only have to deal with JSON in 2 places in a program: Once when reading JSON data and once when outputting data.
In between it should not really matter that the data used to be JSON or should be converted to it.
You should not need any special intermediate structures but only the elements that the respective programming language provides anyway.

This is exactly the approach of this UDF:
There is the function _JSON_Parse(), which converts an arbitrary JSON string into (nested) pure AutoIt data types (Arrays, Maps, Strings, Numbers, Null, True, False).
And on the other side we have the function _JSON_Generate(), which generates a JSON string from arbitrary (nested) AutoIt data structures.

## Import and export JSON
So how to use - let`s give an example:

```AutoIt
#include "JSON.au3"

Global $s_String = '[{"id":"4434156","url":"https://legacy.sky.com/v2/schedules/4434156","title":"468_CORE_1_R.4 Schedule","time_zone":"London","start_at":"2017/08/10 19:00:00 +0100","end_at":null,"notify_user":false,"delete_at_end":false,"executions":[],"recurring_days":[],"actions":[{"type":"run","offset":0}],"next_action_name":"run","next_action_time":"2017/08/10 14:00:00 -0400","user":{"id":"9604","url":"https://legacy.sky.com/v2/users/9604","login_name":"robin@ltree.com","first_name":"Robin","last_name":"John","email":"robin@ltree.com","role":"admin","deleted":false},"region":"EMEA","can_edit":true,"vm_ids":null,"configuration_id":"19019196","configuration_url":"https://legacy.sky.com/v2/configurations/19019196","configuration_name":"468_CORE_1_R.4"},{"id":"4444568","url":"https://legacy.sky.com/v2/schedules/4444568","title":"468_CORE_1_R.4 Schedule","time_zone":"London","start_at":"2017/08/11 12:00:00 +0100","end_at":null,"notify_user":false,"delete_at_end":false,"executions":[],"recurring_days":[],"actions":[{"type":"suspend","offset":0}],"next_action_name":"suspend","next_action_time":"2017/08/11 07:00:00 -0400","user":{"id":"9604","url":"https://legacy.sky.com/v2/users/9604","login_name":"robin@ltree.com","first_name":"Robin","last_name":"John","email":"robin@ltree.com","role":"admin","deleted":false},"region":"EMEA","can_edit":true,"vm_ids":null,"configuration_id":"19019196","configuration_url":"https://legacy.sky.com/v2/configurations/19019196","configuration_name":"468_CORE_1_R.4"}]'

; ================= parse the JSON-String into a nested AutoIt data structure ==============
$o_Object = _JSON_Parse($s_String)

; ================= query values from the structure directly with AutoIt syntax ============
$s_Type = $o_Object[1].actions[0].type
ConsoleWrite("type: " & $s_Type & @CRLF)

;  ; ================= query values via _JSON_Get() (safer and clearer) =======================
$s_Type = _JSON_Get($o_Object, "[1].actions[0].type")
ConsoleWrite("type: " & $s_Type & @CRLF & @CRLF)

;  ; ================= convert AutoIt data structures into a JSON string ======================
ConsoleWrite(_JSON_Generate($o_Object) & @CRLF & @CRLF)
;  ; compact form:
ConsoleWrite(_JSON_Generate($o_Object, "", "", "", "", "", "") & @CRLF & @CRLF)
```

## Handling nested data structures
JSON is often very nested. The resulting AutoIt data is therefore naturally also nested, which makes it somewhat cumbersome to process with pure AutoIt on-board methods.

For this reason, the UDF comes with a few helper functions that make life with this data easier.
One of them is _JSON_Get(), which allows you to access deeply nested data with a simple query syntax.
On the other hand there is the function _JSON_addChangeDelete() with which you can (the name already says it) change, add and delete data.
You can even easily create deeply nested structures with a single call.

Again, here is a small example of how to use it:
```AutoIt
#include "JSON.au3"

Global $mMap ; target variable

; Create a structure to manage the employees of different companies in their respective company sites:
_JSON_addChangeDelete($mMap, "our company.company sites[1].employee[0]", "John Johnson")
_JSON_addChangeDelete($mMap, "our company.company sites[1].employee[1]", "Margret Margretson")
_JSON_addChangeDelete($mMap, "our company.company sites[3].employee[0]", "Betty Bettinson")

; Change a value - e.g. replace the employee "John Johnson"
_JSON_addChangeDelete($mMap, "our company.company sites[1].employee[0]", "Mark Marcusson")

; delete the second employee in the 2nd site ("Margret Margretson")
_JSON_addChangeDelete($mMap, "our company.company sites[1].employee[1]")

; show the resulting data structure
ConsoleWrite(_JSON_Generate($mMap) & @CRLF & @CRLF)
```
Strictly speaking, these functions should not even have "JSON" in their names, since they are generally applied to data structures in AutoIt.
However, since they are often used in the JSON environment, we allow ourselves this small inaccuracy.
