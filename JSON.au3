#include-once
#include <String.au3>
#include <Array.au3>

;  ; if AutoIt-Version without maps is used
;  #ignorefunc MapExists, MapKeys


; #FUNCTION# ======================================================================================
; Name ..........: _JSON_Get
; Description ...: query nested AutoIt-datastructure with a simple query string with syntax:
;                  DictionaryKey1.DictionaryKey2.[ArrayIndex1].DictionaryKey3...
; Syntax ........: _JSON_Get(ByRef $o_Object, Const $s_Pattern)
; Parameters ....: $o_Object      - a nested AutoIt datastructure (Arrays, Dictionaries, basic scalar types)
;                  $s_Pattern     - query pattern like described above
; Return values .: Success - Return the queried object out of the nested datastructure
;                  Failure - Return "" and set @error to:
;        				@error = 1 - pattern is not correct
;                              = 2 - keyname query to none dictionary object
;                              = 3 - keyname queried not exists in dictionary
;                              = 4 - index query on none array object
;                              = 5 - index out of array range
; Author ........: AspirinJunkie
; =================================================================================================
Func _JSON_Get(ByRef $o_Object, Const $s_Pattern)
	Local $o_Current = $o_Object, $d_Val
	Local $a_Tokens = StringRegExp($s_Pattern, '\[(\d+)\]|([^\.\[\]]+)', 4)
	If @error Then Return SetError(1, @error, "")

	For $a_CurToken In $a_Tokens

		If UBound($a_CurToken) = 3 Then ; KeyName
			Switch VarGetType($o_Current)
				Case "Object"
					If Not IsObj($o_Current) Or ObjName($o_Current) <> "Dictionary" Then Return SetError(2, 0, "")
					If Not $o_Current.Exists($a_CurToken[2]) Then Return SetError(3, 0, "")

					$o_Current = $o_Current($a_CurToken[2])
				Case "Map"
					If Not MapExists($o_Current, $a_CurToken[2]) Then Return SetError(3, 0, "")

					$o_Current = $o_Current[$a_CurToken[2]]
			EndSwitch
		ElseIf UBound($a_CurToken) = 2 Then ; ArrayIndex
			If (Not IsArray($o_Current)) Or UBound($o_Current, 0) <> 1 Then Return SetError(4, UBound($o_Current, 0), "")
			$d_Val = Int($a_CurToken[1])
			If $d_Val < 0 Or $d_Val >= UBound($o_Current) Then Return SetError(5, $d_Val, "")
			$o_Current = $o_Current[$d_Val]
		EndIf
	Next
	Return $o_Current
EndFunc   ;==>_JSON_Get


; #FUNCTION# ======================================================================================
; Name ..........: _JSON_Generate
; Description ...: convert a JSON-formatted string into a nested structure of AutoIt-datatypes
; Syntax ........: _JSON_Generate($o_Object, $s_ObjIndent = @TAB, $s_ObjDelEl = @CRLF, $s_ObjDelKey = " ", $s_ObjDelVal = "", $s_ArrIndent = @TAB, $s_ArrDelEl = @CRLF, $i_Level = 0)
; Parameters ....: $s_String      - a string formatted as JSON
;                  [$s_ObjIndent] - indent for object elements (only reasonable if $s_ObjDelEl contains a line skip
;                  [$s_ObjDelEl]  - delimiter between object elements
;                  [$s_ObjDelKey] - delimiter between keyname and ":" in object
;                  [$s_ObjDelVal] - delimiter between ":" and value in object
;                  [$s_ArrIndent] - indent for array elements (only reasonable if $s_ArrDelEl contains a line skip)
;                  [$s_ArrDelEl]  - delimiter between array elements
;                  [$i_Level]     - search position where to start (normally don't touch!)
; Return values .: Success - Return a JSON formatted string
;                  Failure - Return ""
; Author ........: AspirinJunkie
; =================================================================================================
Func _JSON_Generate($o_Object, $s_ObjIndent = @TAB, $s_ObjDelEl = @CRLF, $s_ObjDelKey = "", $s_ObjDelVal = " ", $s_ArrIndent = @TAB, $s_ArrDelEl = @CRLF, $i_Level = 0)
	Local Static $s_JSON_String
	If $i_Level = 0 Then $s_JSON_String = ""

	Switch VarGetType($o_Object)
		Case "String"
			__JSON_FormatString($o_Object)
			$s_JSON_String &= '"' & $o_Object & '"'
		Case "Int32", "Int64", "Float", "Double"
			$s_JSON_String &= String($o_Object)
;~ 			$s_JSON_String &= StringRegExpReplace(StringFormat("%g", $o_Object), '(-?(?>0|[1-9]\d*)(?>\.\d+)?)(?:([eE][-+]?)0*(\d+))?', "$1$2$3", 1)
		Case "Bool"
			$s_JSON_String &= StringLower($o_Object)
		Case "Keyword"
			If IsKeyword($o_Object) = 2 Then $s_JSON_String &= "null"
		Case "Binary"
			$s_JSON_String &= '"' & _Base64Encode($o_Object) & '"'
		Case "Array"
			If UBound($o_Object, 0) = 2 Then $o_Object = __Array2dToAinA($o_Object)
			If UBound($o_Object) = 0 Then
				$s_JSON_String &= "[]"
			Else
				$s_JSON_String &= "[" & $s_ArrDelEl
				For $o_Value In $o_Object
					$s_JSON_String &= _StringRepeat($s_ArrIndent, $i_Level + 1)
					_JSON_Generate($o_Value, $s_ObjIndent, $s_ObjDelEl, $s_ObjDelKey, $s_ObjDelVal, $s_ArrIndent, $s_ArrDelEl, $i_Level + 1)

					$s_JSON_String &= "," & $s_ArrDelEl
				Next
				$s_JSON_String = StringTrimRight($s_JSON_String, StringLen("," & $s_ArrDelEl)) & $s_ArrDelEl & _StringRepeat($s_ArrIndent, $i_Level) & "]"
			EndIf
		Case "Object"
			If ObjName($o_Object) = "Dictionary" Then
				Local $s_KeyTemp, $o_Value
				If $o_Object.Count() = 0 Then
					$s_JSON_String &= "{}"
				Else
					$s_JSON_String &= "{" & $s_ObjDelEl
					For $s_Key In $o_Object.Keys
						$s_KeyTemp = $s_Key
						$o_Value = $o_Object($s_Key)
						__JSON_FormatString($s_KeyTemp)

						$s_JSON_String &= _StringRepeat($s_ObjIndent, $i_Level + 1) & '"' & $s_KeyTemp & '"' & $s_ObjDelKey & ':' & $s_ObjDelVal

						_JSON_Generate($o_Value, $s_ObjIndent, $s_ObjDelEl, $s_ObjDelKey, $s_ObjDelVal, $s_ArrIndent, $s_ArrDelEl, $i_Level + 1)

						$s_JSON_String &= "," & $s_ObjDelEl
					Next
					$s_JSON_String = StringTrimRight($s_JSON_String, StringLen("," & $s_ObjDelEl)) & $s_ObjDelEl & _StringRepeat($s_ObjIndent, $i_Level) & "}"
				EndIf
			EndIf
		Case "Map"
			Local $s_KeyTemp, $o_Value
			If UBound($o_Object) = 0 Then
				$s_JSON_String &= "{}"
			Else
				$s_JSON_String &= "{" & $s_ObjDelEl
				For $s_Key In MapKeys($o_Object)
					$s_KeyTemp = $s_Key
					$o_Value = $o_Object[$s_Key]
					__JSON_FormatString($s_KeyTemp)

					$s_JSON_String &= _StringRepeat($s_ObjIndent, $i_Level + 1) & '"' & $s_KeyTemp & '"' & $s_ObjDelKey & ':' & $s_ObjDelVal

					_JSON_Generate($o_Value, $s_ObjIndent, $s_ObjDelEl, $s_ObjDelKey, $s_ObjDelVal, $s_ArrIndent, $s_ArrDelEl, $i_Level + 1)

					$s_JSON_String &= "," & $s_ObjDelEl
				Next
				$s_JSON_String = StringTrimRight($s_JSON_String, StringLen("," & $s_ObjDelEl)) & $s_ObjDelEl & _StringRepeat($s_ObjIndent, $i_Level) & "}"
			EndIf
	EndSwitch

	If $i_Level = 0 Then
		Local $s_Temp = $s_JSON_String
		$s_JSON_String = ""
		Return $s_Temp
	EndIf
EndFunc   ;==>_JSON_Generate


; #FUNCTION# ======================================================================================
; Name ..........: _JSON_Parse
; Description ...: convert a JSON-formatted string into a nested structure of AutoIt-datatypes
; Syntax ........: _JSON_Parse(ByRef $s_String, $i_Os = 1)
; Parameters ....: $s_String      - a string formatted as JSON
;                  [$i_Os]        - search position where to start (normally don't touch!)
; Return values .: Success - Return a nested structure of AutoIt-datatypes
;                       @extended = next string offset
;                  Failure - Return "" and set @error to:
;        				@error = 1 - part is not json-syntax
;                              = 2 - key name in object part is not json-syntax
;                              = 3 - value in object is not correct json
;                              = 4 - delimiter or object end expected but not gained
; Author ........: AspirinJunkie
; =================================================================================================
Func _JSON_Parse(ByRef $s_String, $i_Os = 1)
	Local $i_OsC = $i_Os, $o_Current, $o_Value
	; Inside a character class, \R is treated as an unrecognized escape sequence, and so matches the letter "R" by default, but causes an error if
	Local Static $s_RE_s = '[\x20\r\n\t]', _ ;  = [\x20\x09\x0A\x0D]
			$s_RE_G_String = '\G[\x20\r\n\t]*"((?>[^\\"]+|\\.)*+)"', _    ; only for real valid JSON: "((?>[^\\"]+|\\[\\"bfnrtu\/])*)"        second (a little slower) alternative: "((?>[^\\"]+|\\\\|\\.)*)"
			$s_RE_G_Number = '\G[\x20\r\n\t]*(-?(?>0|[1-9]\d*)(?>\.\d+)?(?>[eE][-+]?\d+)?)', _
			$s_RE_G_KeyWord = '\G[\x20\r\n\t]*\b(null|true|false)\b', _
			$s_RE_G_Object_Begin = '\G[\x20\r\n\t]*\{', _
			$s_RE_G_Object_Key = '\G[\x20\r\n\t]*"((?>[^\\"]+|\\.)*+)"[\x20\r\n\t]*:', _
			$s_RE_G_Object_Further = '\G[\x20\r\n\t]*,', _
			$s_RE_G_Object_End = '\G[\x20\r\n\t]*\}', _
			$s_RE_G_Array_Begin = '\G[\x20\r\n\t]*\[', _
			$s_RE_G_Array_End = '\G[\x20\r\n\t]*\]'

	$o_Current = StringRegExp($s_String, $s_RE_G_String, 1, $i_Os) ; String
	If Not @error Then Return SetExtended(@extended, __JSON_ParseString($o_Current[0]))

	StringRegExp($s_String, $s_RE_G_Object_Begin, 1, $i_Os) ; Object
	If Not @error Then
		$i_OsC = @extended
		Local $s_Key, $o_Value, $a_T

		Local $o_Current[]

		StringRegExp($s_String, $s_RE_G_Object_End, 1, $i_OsC)     ; check for empty object
		If Not @error Then     ; empty object
			$i_OsC = @extended
		Else
			Do
				$a_T = StringRegExp($s_String, $s_RE_G_Object_Key, 1, $i_OsC)     ; key of element
				If @error Then Return SetError(2, $i_OsC, "")
				$i_OsC = @extended

				$s_Key = __JSON_ParseString($a_T[0])

				$o_Value = _JSON_Parse($s_String, $i_OsC)
				If @error Then Return SetError(3, $i_OsC, "")
				$i_OsC = @extended

				$o_Current[$s_Key] = $o_Value     ; add key:value to map

				StringRegExp($s_String, $s_RE_G_Object_Further, 1, $i_OsC)     ; more elements
				If Not @error Then
					$i_OsC = @extended
					ContinueLoop
				Else
					StringRegExp($s_String, $s_RE_G_Object_End, 1, $i_OsC)     ; end of array
					If Not @error Then
						$i_OsC = @extended
						ExitLoop
					Else
						Return SetError(4, $i_OsC, "")
					EndIf
				EndIf
			Until False
		EndIf

		Return SetExtended($i_OsC, $o_Current)
	EndIf


	StringRegExp($s_String, $s_RE_G_Array_Begin, 1, $i_Os) ; Array
	If Not @error Then
		$i_OsC = @extended
		Local $o_Current[]	; empty array list (AutoIt map)

		StringRegExp($s_String, $s_RE_G_Array_End, 1, $i_OsC) ; check for empty array
		If Not @error Then ; empty array
			$i_OsC = @extended
			Return SetExtended($i_OsC, $o_Current)
		EndIf

		Do
			$o_Value = _JSON_Parse($s_String, $i_OsC)
			If @error Then Return SetError(3, $i_OsC, "")
			$i_OsC = @extended

			MapAppend($o_Current, $o_Value)	; add value to array list

			StringRegExp($s_String, $s_RE_G_Object_Further, 1, $i_OsC) ; more elements
			If Not @error Then
				$i_OsC = @extended
				ContinueLoop
			Else
				StringRegExp($s_String, $s_RE_G_Array_End, 1, $i_OsC) ; end of array
				If Not @error Then
					$i_OsC = @extended
					ExitLoop
				Else
					Return SetError(5, $i_OsC, "")
				EndIf
			EndIf

		Until False
		Return SetExtended($i_OsC, $o_Current)
	EndIf

	$o_Current = StringRegExp($s_String, $s_RE_G_Number, 1, $i_Os) ; Number
	If Not @error Then Return SetExtended(@extended, Number($o_Current[0]))

	$o_Current = StringRegExp($s_String, $s_RE_G_KeyWord, 1, $i_Os) ; KeyWord
	If Not @error Then Return SetExtended(@extended, Execute($o_Current[0])) ; $o_Current[0] = "null" ? Null : $o_Current[0] = "true" ? True : False)

	Return SetError(1, $i_OsC, "")
EndFunc   ;==>_JSON_Parse


; helper function for converting a json formatted string into an AutoIt-string
Func __JSON_ParseString(ByRef $s_String)
	Local $aB[5]

	Local $a_RE = StringRegExp($s_String, '\\\\(*SKIP)(?!)|(\\["bf/]|\\u[[:xdigit:]]{4})', 3)
	If Not @error Then
		For $s_Esc In $a_RE
			Switch StringMid($s_Esc, 2, 1)
				Case "b"
					If $aB[0] Then ContinueLoop
					$s_String = StringRegExpReplace($s_String, '\\\\(*SKIP)(*FAIL)|\\b', Chr(8))
					$aB[0] = True
				Case "f"
					If $aB[1] Then ContinueLoop
					$s_String = StringRegExpReplace($s_String, '\\\\(*SKIP)(*FAIL)|\\f', Chr(12))
					$aB[1] = True
				Case "/"
					If $aB[2] Then ContinueLoop
					$s_String = StringRegExpReplace($s_String, '\\\\(*SKIP)(*FAIL)|\\/', "/")
					$aB[2] = True
				Case '"'
					If $aB[3] Then ContinueLoop
					$s_String = StringRegExpReplace($s_String, '\\\\(*SKIP)(*FAIL)|\\"', '"')
					$aB[3] = True
				Case "u"
					If $aB[4] Then ContinueLoop
					Local $a_RE = StringRegExp($s_String, '\\\\(*SKIP)(?!)|\\u\K[[:xdigit:]]{4}', 3)
					If Not @error Then
						If UBound($a_RE) > 10 Then _ArrayUnique($a_RE)
						For $s_Code In $a_RE
							$s_String = StringReplace($s_String, "\u" & $s_Code, ChrW(Dec($s_Code)), 0, 1)
						Next
						$aB[4] = True
					EndIf
			EndSwitch
		Next
	EndIf

	; converts \n \r \t \\ implicit:
	Return StringFormat(StringReplace($s_String, "%", "%%", 0, 1))
EndFunc   ;==>__JSON_ParseString

; helper function for converting a AutoIt-sting into a json formatted string
Func __JSON_FormatString(ByRef $s_String)
	$s_String = StringReplace($s_String, '\', '\\', 0, 1)
	$s_String = StringReplace($s_String, Chr(8), "\b", 0, 1)
	$s_String = StringReplace($s_String, Chr(12), "\f", 0, 1)
	$s_String = StringReplace($s_String, @CRLF, "\n", 0, 1)
	$s_String = StringReplace($s_String, @CR, "\r", 0, 1)
	$s_String = StringReplace($s_String, '"', '\"', 0, 1)
EndFunc   ;==>__JSON_FormatString


; #FUNCTION# ======================================================================================
; Name ..........: _Base64Encode
; Description ...: convert a binary- or string-Input into BASE64 (or optional base64url) format
;                  mainly a wrapper for the CryptBinaryToString API-function
; Syntax ........: _Base64Encode(Const ByRef $s_Input, [Const $b_base64url = False])
; Parameters ....: $s_Input       - binary data or string which should be converted
;                  [$b_base64url] - If true the output is in base64url-format instead of base64
; Return values .: Success - Return base64 (or base64url) formatted string
;                  Failure - Return "" and set @error to:
;        				@error = 1 - failure at the first run to calculate the output size
;						       = 2 - failure at the second run to calculate the output
; Author ........: AspirinJunkie
; Example .......: Yes
;                  $s_Base64String = _Base64Encode("This is my test")
; =================================================================================================
Func _Base64Encode(Const ByRef $s_Input, Const $b_base64url = False)
	Local $b_Input = IsBinary($s_Input) ? $s_Input : Binary($s_Input)

	Local $t_BinArray = DllStructCreate("BYTE[" & BinaryLen($s_Input) & "]")
	DllStructSetData($t_BinArray, 1, $b_Input)

	Local $h_DLL_Crypt32 = DllOpen("Crypt32.dll")

	; first run to calculate needed size of output buffer
	Local $a_Ret = DllCall($h_DLL_Crypt32, "BOOLEAN", "CryptBinaryToString", _
			"STRUCT*", $t_BinArray, _     ; *pbBinary
			"DWORD", DllStructGetSize($t_BinArray), _     ; cbBinary
			"DWORD", 1, _     ; dwFlags
			"PTR", Null, _ ; pszString
			"DWORD*", 0)
	If @error Or Not IsArray($a_Ret) Or $a_Ret[0] = 0 Then Return SetError(1, @error, DllClose($h_DLL_Crypt32))

	; second run to calculate base64-string:
	Local $t_Output = DllStructCreate("CHAR Out[" & $a_Ret[5] & "]")
	Local $a_Ret2 = DllCall($h_DLL_Crypt32, "BOOLEAN", "CryptBinaryToString", _
			"STRUCT*", $t_BinArray, _     ; *pbBinary
			"DWORD", DllStructGetSize($t_BinArray), _     ; cbBinary
			"DWORD", 1, _     ; dwFlags
			"STRUCT*", $t_Output, _ ; pszString
			"DWORD*", $a_Ret[5])
	If @error Or Not IsArray($a_Ret2) Or $a_Ret2[0] = 0 Then Return SetError(2, @error, DllClose($h_DLL_Crypt32))

	Local $s_Output = $t_Output.Out
	If StringInStr($s_Output, "=", 1, 1) Then $s_Output = StringLeft($s_Output, StringInStr($s_Output, "=", 1, 1) - 1)

	If $b_base64url Then $s_Output = StringReplace(StringReplace($s_Output, "/", "_", 0, 1), "+", "-", 0, 1)

	DllClose($h_DLL_Crypt32)
	Return $s_Output
EndFunc   ;==>_Base64Encode


; #FUNCTION# ======================================================================================
; Name ..........: _Base64Decode
; Description ...: decode data which is coded as a base64-string into binary form
;                  mainly a wrapper for the CryptStringToBinary API-function
; Syntax ........: _Base64Decode(Const ByRef $s_Input, [Const $b_base64url = False])
; Parameters ....: $s_Input       - string in base64-format
;                  [$b_base64url] - If true the output is in base64url-format instead of base64
; Return values .: Success - Return base64 (or base64url) formatted string
;                  Failure - Return "" and set @error to:
;						@error = 1 - failure at the first run to calculate the output size
;						       = 2 - failure at the second run to calculate the output
; Author ........: AspirinJunkie
; Example .......: Yes
;                  MsgBox(0, '', BinaryToString(_Base64Decode("VGVzdA")))
; =================================================================================================
Func _Base64Decode(Const ByRef $s_Input, Const $b_base64url = False)
	Local $h_DLL_Crypt32 = DllOpen("Crypt32.dll")

	; hier noch einen Reg-Ex zum testen ob String base64-codiert ist

	; first run to calculate needed size of output buffer
	Local $a_Ret = DllCall($h_DLL_Crypt32, "BOOLEAN", "CryptStringToBinary", _
			"STR", $s_Input, _ ; pszString
			"DWORD", 0, _ ; cchString
			"DWORD", 1, _ ; dwFlags
			"PTR", Null, _ ; pbBinary
			"DWORD*", 0, _ ; pcbBinary
			"PTR", Null, _ ; pdwSkip
			"PTR", Null) ; pdwFlags
	Local $t_Ret = DllStructCreate("BYTE Out[" & $a_Ret[5] & "]")
	If @error Or Not IsArray($a_Ret) Or $a_Ret[0] = 0 Then Return SetError(1, @error, DllClose($h_DLL_Crypt32))


	; second run to calculate the output data:
	Local $a_Ret2 = DllCall($h_DLL_Crypt32, "BOOLEAN", "CryptStringToBinary", _
			"STR", $s_Input, _ ; pszString
			"DWORD", 0, _ ; cchString
			"DWORD", 1, _ ; dwFlags
			"STRUCT*", $t_Ret, _ ; pbBinary
			"DWORD*", $a_Ret[5], _ ; pcbBinary
			"PTR", Null, _ ; pdwSkip
			"PTR", Null) ; pdwFlags
	If @error Or Not IsArray($a_Ret2) Or $a_Ret2[0] = 0 Then Return SetError(2, @error, DllClose($h_DLL_Crypt32))
	DllClose($h_DLL_Crypt32)

	Local $s_Output = $t_Ret.Out
	If $b_base64url Then $s_Output = StringReplace(StringReplace($s_Output, "_", "/", 0, 1), "-", "+", 0, 1)

	Return $s_Output
EndFunc   ;==>_Base64Decode

; #FUNCTION# ======================================================================================
; Name ..........: __Array2dToAinA()
; Description ...: Convert a 2D array into a Arrays in Array
; Syntax ........: _Array2dToAinA(ByRef $A)
; Parameters ....: $A             - the 2D-Array  which should be converted
; Return values .: Success: a Arrays in Array build from the input array
;                  Failure: False
;                     @error = 1: $A is'nt an 2D array
; Author ........: AspirinJunkie
; =================================================================================================
Func __Array2dToAinA(ByRef $A, $bTruncEmpty = True)
	If UBound($A, 0) <> 2 Then Return SetError(1, UBound($A, 0), False)
	Local $N = UBound($A), $u = UBound($A, 2)
	Local $a_Ret[$N]

	IF $bTruncEmpty Then
		For $i = 0 To $N - 1
			Local $x = $u -1
			While IsString($A[$i][$x]) And $A[$i][$x] = ""
				$x -= 1
			WEnd
			Local $t[$x+1]
			For $j = 0 To $x
				$t[$j] = $A[$i][$j]
			Next
			$a_Ret[$i] = $t
		Next
	Else
		For $i = 0 To $N - 1
			Local $t[$u]
			For $j = 0 To $u - 1
				$t[$j] = $A[$i][$j]
			Next
			$a_Ret[$i] = $t
		Next
	EndIf
	Return $a_Ret
EndFunc   ;==>__Array2dToAinA

; #FUNCTION# ======================================================================================
; Name ..........: __ArrayAinATo2d()
; Description ...: Convert a Arrays in Array into a 2D array
; Syntax ........: __ArrayAinATo2d(ByRef $A)
; Parameters ....: $A             - the arrays in array which should be converted
; Return values .: Success: a 2D Array build from the input array
;                  Failure: False
;                     @error = 1: $A is'nt an 1D array
;                            = 2: $A is empty
;                            = 3: first element isn't a array
; Author ........: AspirinJunkie
; =================================================================================================
Func __ArrayAinATo2d(ByRef $A)
	If UBound($A, 0) <> 1 Then Return SetError(1, UBound($A, 0), False)
	Local $N = UBound($A)
	If $N < 1 Then Return SetError(2, $N, False)
	Local $u = UBound($A[0])
	If $u < 1 Then Return SetError(3, $u, False)

	Local $a_Ret[$N][$u]

	For $i = 0 To $N - 1
		Local $t = $A[$i]
		If UBound($t) > $u Then ReDim $a_Ret[$N][UBound($t)]
		For $j = 0 To UBound($t) - 1
			$a_Ret[$i][$j] = $t[$j]
		Next
	Next
	Return $a_Ret
EndFunc   ;==>__ArrayAinATo2d


