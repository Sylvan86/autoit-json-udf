#include "JSON.au3"
Global $s_String = '[{"id":"4434156","url":"https://legacy.sky.com/v2/schedules/4434156","title":"468_CORE_1_R.4 Schedule","time_zone":"London","start_at":"2017/08/10 19:00:00 +0100","end_at":null,"notify_user":false,"delete_at_end":false,"executions":[],"recurring_days":[],"actions":[{"type":"run","offset":0}],"next_action_name":"run","next_action_time":"2017/08/10 14:00:00 -0400","user":{"id":"9604","url":"https://legacy.sky.com/v2/users/9604","login_name":"robin@ltree.com","first_name":"Robin","last_name":"John","email":"robin@ltree.com","role":"admin","deleted":false},"region":"EMEA","can_edit":true,"vm_ids":null,"configuration_id":"19019196","configuration_url":"https://legacy.sky.com/v2/configurations/19019196","configuration_name":"468_CORE_1_R.4"},{"id":"4444568","url":"https://legacy.sky.com/v2/schedules/4444568","title":"468_CORE_1_R.4 Schedule","time_zone":"London","start_at":"2017/08/11 12:00:00 +0100","end_at":null,"notify_user":false,"delete_at_end":false,"executions":[],"recurring_days":[],"actions":[{"type":"suspend","offset":0}],"next_action_name":"suspend","next_action_time":"2017/08/11 07:00:00 -0400","user":{"id":"9604","url":"https://legacy.sky.com/v2/users/9604","login_name":"robin@ltree.com","first_name":"Robin","last_name":"John","email":"robin@ltree.com","role":"admin","deleted":false},"region":"EMEA","can_edit":true,"vm_ids":null,"configuration_id":"19019196","configuration_url":"https://legacy.sky.com/v2/configurations/19019196","configuration_name":"468_CORE_1_R.4"}]'

; ================= parse the JSON-String into a nested AutoIt data structure ==============
$o_Object = _JSON_Parse($s_String)

; ================= query values from the structure directly with AutoIt syntax ============
$s_Type = ((($o_Object[1])["actions"])[0])["type"]
ConsoleWrite("type: " & $s_Type & @CRLF)

; ================= query values via _JSON_Get() (safer and clearer) =======================
$s_Type = _JSON_Get($o_Object, "[1].actions[0].type")
ConsoleWrite("type: " & $s_Type & @CRLF)

; ================= convert AutoIt data structures into a JSON string ======================
ConsoleWrite(_JSON_Generate($o_Object) & @CRLF & @CRLF)
; compact form:
ConsoleWrite(_JSON_GenerateCompact($o_Object) & @CRLF & @CRLF)

; ================= convert minified JSON file to unminified JSON string =====
$s_File = 'example.min.json'
ConsoleWrite(_JSON_Unminify($s_File) & @CRLF & @CRLF)

; ================= convert unminified JSON file to minified JSON string =====
$s_File = 'example.json'
ConsoleWrite(_JSON_Minify($s_File) & @CRLF)
