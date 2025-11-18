#include-once

; #INDEX# =======================================================================================================================
; Title .........: JSON-UDF
; Version .......: 0.5
; AutoIt Version : 3.3.18.0
; Language ......: english (german maybe by accident)
; Description ...: Function for interacting with JSON data in AutoIt.
;                  This includes import, export as well as helper functions for handling nested AutoIt data structures.
; Author(s) .....: AspirinJunkie, Sven Seyfert (SOLVE-SMART)
; Last changed ..: 2025-11-18
; Link ..........: https://github.com/Sylvan86/autoit-json-udf
; License .......: This work is free.
;                  You can redistribute it and/or modify it under the terms of the Do What The Fuck You Want To Public License, Version 2,
;                  as published by Sam Hocevar.
;                  See http://www.wtfpl.net/ for more details.
; ===============================================================================================================================

; #Function list# =======================================================================================================================
; ---- import and export from or to json ------
;  _JSON_Parse               - converts a JSON-structured string into a nested AutoIt data structure
;  _JSON_Generate            - converts a nested AutoIt data structure into a JSON structured string
;  _JSON_GenerateCompact     - shorthand for _JSON_Generate() to create JSON structured strings as compact as possible
;  _JSON_Unminify            - reads minified (compact) JSON file or string and converts to well readable JSON string
;  _JSON_Minify              - reads unminified (readable) JSON file or string and converts to minified (compact) JSON string
;
; ---- extraction and manipulation of nested AutoIt data structures ----
;  _JSON_Get                 - extract query nested AutoIt-datastructure with a simple selector string
;  _JSON_addChangeDelete     - create a nested AutoIt data structure, change values within existing structures or delete elements from a nested AutoIt data structure
;
; ---- helper functions ----
;      __JSON_FormatString   - converts a string into a json string by escaping the special symbols
;      __JSON_ParseString    - converts a json formatted string into an AutoIt-string by unescaping the json-escapes
;      __JSON_A2DToAinA      - converts a 2D array into a Arrays in Array
;      __JSON_AinAToA2d      - converts a Arrays in Array into a 2D array
;      __JSON_Base64Decode   - decode data which is coded as a base64-string into binary variable
;      __JSON_Base64Encode   - converts a binary- or string-Input into BASE64 (or optional base64url) format
; ===============================================================================================================================

; #FUNCTION# ======================================================================================
; Name ..........: _JSON_Parse
; Description ...: convert a JSON-formatted string into a nested structure of AutoIt-datatypes
; Syntax ........: _JSON_Parse(Const $sString, $iOs = 1)
; Parameters ....: $sString      - a string formatted as JSON
;                  [$iOs]        - search position where to start (normally don't touch!)
; Return values .: Success - Return a nested structure of AutoIt-datatypes
;                       @extended = next string offset
;                  Failure - Return "" and set @error to:
;                       @error = 1 - part is not json-syntax
;                              = 2 - key name in object part is not json-syntax
;                              = 3 - value in object is not correct json
;                              = 4 - delimiter or object end expected but not gained
; Author ........: AspirinJunkie
; =================================================================================================
Func _JSON_Parse(Const $sString, $iOs = 1)
	Local $vValue
	Local Static $sRE_JSONElements = '\G\s*(?>' & _
		'"([^"\\]*+(?>\\.[^"\\]*+)*)"|' & _                              ; String (group 1)
		'(-?(?>0|[1-9]\d*)(?>\.\d+)?(?>[eE][-+]?\d+)?)|' & _             ; Number (group 2)
		'(\{)|' & _                                                      ; Object begin (group 3)
		'(\[)|' & _                                                      ; Array begin (group 4)
		'\b(null|true|false)\b)', _                                      ; Keywords (group 5)
		$sRE_Object_Key     = '\G\s*"([^"\\]*+(?>\\.[^"\\]*+)*)"\s*:', _ ; the key of an object
		$sRE_Object_Further = '\G\s*,',                         _        ; object element separator
		$sRE_Object_End     = '\G\s*\}',                        _        ; object end
		$sRE_Array_End      = '\G\s*\]'                                  ; array end

	Local $aMatch = StringRegExp($sString, $sRE_JSONElements, 1, $iOs)
	If @error Then Return SetError(1, $iOs, "")
	$iOs = @extended

	; Determine type of current element and process accordingly
	Switch UBound($aMatch)
		Case 1 ; String
			Return SetExtended($iOs, StringInStr($aMatch[0], "\", 1) ? __JSON_ParseString($aMatch[0]) : $aMatch[0])
		Case 2 ; Number
			Return SetExtended($iOs, Number($aMatch[1]))
		Case 3 ; Object begin
			Local $oCurrent[], $aKey

			; Check for empty object
			StringRegExp($sString, $sRE_Object_End, 1, $iOs)
			If Not @error Then Return SetExtended(@extended, $oCurrent)

			Do
				; extract the element key
				$aKey = StringRegExp($sString, $sRE_Object_Key, 1, $iOs)
				If @error Then Return SetError(2, $iOs, "")
				$iOs = @extended

				; extract the element value
				$vValue = _JSON_Parse($sString, $iOs)
				If @error Then Return SetError(3, $iOs, "")
				$iOs = @extended
	
				; add current element value to map linked to the current element key
				$oCurrent[(StringInStr($aKey[0], "\", 1) ? __JSON_ParseString($aKey[0]) : $aKey[0])] = $vValue
		
				; check for further elements in the object
				StringRegExp($sString, $sRE_Object_Further, 1, $iOs) ; more elements
				If Not @error Then
					$iOs = @extended
					ContinueLoop
				Else
					StringRegExp($sString, $sRE_Object_End, 1, $iOs)
					If Not @error Then                                ; end of object reached
						Return SetExtended(@extended, $oCurrent)
					Else                                              ; syntax error
						Return SetError(4, $iOs, "")
					EndIf
				EndIf
			Until False
		Case 4 ; Array begin
			; Start with larger initial array size for better performance
			Local $aCurrent[16], $iSize = 16, $iCount = 0

			; Check for empty array
			StringRegExp($sString, $sRE_Array_End, 1, $iOs)
			If Not @error Then
				ReDim $aCurrent[0]
				Return SetExtended(@extended, $aCurrent)
			EndIf

			Do
				$vValue = _JSON_Parse($sString, $iOs)
				If @error Then Return SetError(3, $iOs, "")
				$iOs = @extended
		
				; array resize if necessary
				If $iCount >= $iSize Then
					$iSize += $iSize
					ReDim $aCurrent[$iSize]
				EndIf
				$aCurrent[$iCount] = $vValue
				$iCount += 1
		
				; check for further elements in the array
				StringRegExp($sString, $sRE_Object_Further, 1, $iOs)
				If Not @error Then                                      ; more elements found
					$iOs = @extended
					ContinueLoop
				Else
					StringRegExp($sString, $sRE_Array_End, 1, $iOs)     ; end of array reached
					If Not @error Then
						If $iCount <> $iSize Then ReDim $aCurrent[$iCount]
						Return SetExtended(@extended, $aCurrent)
					Else                                                ; syntax error
						Return SetError(5, $iOs, "")
					EndIf
				EndIf
			Until False
		Case 5 ; Keywords
			Return SetExtended($iOs, Execute($aMatch[4]))
	EndSwitch
	
	Return SetError(1, $iOs, "")
EndFunc   ;==>_JSON_Parse

; #FUNCTION# ======================================================================================
; Name ..........: _JSON_Generate
; Description ...: converts a nested AutoIt data structure into a JSON structured string
; Syntax ........: _JSON_Generate($oObject, $sObjIndent = @TAB, $sObjDelEl = @CRLF, $sObjDelKey = " ", $sObjDelVal = "", $sArrIndent = @TAB, $sArrDelEl = @CRLF, $iLevel = 0)
; Parameters ....: $oObject      - [nested] AutoIt data structure
;                  [$sObjIndent] - indent for object elements (only reasonable if $sObjDelEl contains a line skip
;                  [$sObjDelEl]  - delimiter between object elements
;                  [$sObjDelKey] - delimiter between keyname and ":" in object
;                  [$sObjDelVal] - delimiter between ":" and value in object
;                  [$sArrIndent] - indent for array elements (only reasonable if $sArrDelEl contains a line skip)
;                  [$sArrDelEl]  - delimiter between array elements
;                  [$iLevel]     - search position where to start (normally don't touch!)
; Return values .: Success - Return a JSON formatted string
;                  Failure - Return ""
; Author ........: AspirinJunkie
; =================================================================================================
Func _JSON_Generate($oObject, $sObjIndent = @TAB, $sObjDelEl = @CRLF, $sObjDelKey = "", $sObjDelVal = " ", $sArrIndent = @TAB, $sArrDelEl = @CRLF, $iLevel = 0)
	Local Static $sJSON_String
	Local Static $aObjIndCache[0], $aArrIndCache[0]
	Local $sKeyTemp, $oValue
	If $iLevel = 0 Then 
		$sJSON_String = ""
		Redim $aObjIndCache[20]
		Redim $aArrIndCache[20]
		$aObjIndCache[1] = $sObjIndent
		$aArrIndCache[1] = $sArrIndent
	EndIf

	; Cache to avoid StringRepeat
	If UBound($aObjIndCache) < $iLevel + 2 Then ; for structures with large amount of levels
		Redim $aObjIndCache[$iLevel + 2]
		Redim $aArrIndCache[$iLevel + 2]
	EndIf
	; calculate the current indentation
	If $aArrIndCache[$iLevel + 1] = "" And $sArrIndent <> "" Then $aArrIndCache[$iLevel + 1] = $aArrIndCache[$iLevel] & $sArrIndent
	If $aObjIndCache[$iLevel + 1] = "" And $sObjIndent <> "" Then $aObjIndCache[$iLevel + 1] = $aObjIndCache[$iLevel] & $sObjIndent
	
	Switch VarGetType($oObject)
		Case "String"
			$sJSON_String &= '"' & __JSON_FormatString($oObject) & '"'
		Case "Int32", "Int64", "Float", "Double"
			$sJSON_String &= String($oObject)
		Case "Bool"
			$sJSON_String &= StringLower($oObject)
		Case "Keyword"
			If IsKeyword($oObject) = 2 Then $sJSON_String &= "null"
		Case "Binary"
			$sJSON_String &= '"' & __JSON_Base64Encode($oObject) & '"'
		Case "Array"
			If UBound($oObject, 0) = 2 Then $oObject = __JSON_A2DToAinA($oObject)
			If UBound($oObject) = 0 Then
				$sJSON_String &= "[]"
			Else
				$sJSON_String &= "[" & $sArrDelEl
				For $oValue In $oObject
					$sJSON_String &= $aArrIndCache[$iLevel + 1]
					_JSON_Generate($oValue, $sObjIndent, $sObjDelEl, $sObjDelKey, $sObjDelVal, $sArrIndent, $sArrDelEl, $iLevel + 1)

					$sJSON_String &= "," & $sArrDelEl
				Next
				$sJSON_String = StringTrimRight($sJSON_String, StringLen("," & $sArrDelEl)) & $sArrDelEl & $aArrIndCache[$iLevel] & "]"
			EndIf
		Case "Object"
			If ObjName($oObject) = "Dictionary" Then
				If $oObject.Count() = 0 Then
					$sJSON_String &= "{}"
				Else
					$sJSON_String &= "{" & $sObjDelEl
					For $sKey In $oObject.Keys
						$sKeyTemp = $sKey
						$oValue = $oObject($sKey)

						$sJSON_String &= $aObjIndCache[$iLevel + 1] & '"' & __JSON_FormatString($sKeyTemp) & '"' & $sObjDelKey & ':' & $sObjDelVal

						_JSON_Generate($oValue, $sObjIndent, $sObjDelEl, $sObjDelKey, $sObjDelVal, $sArrIndent, $sArrDelEl, $iLevel + 1)

						$sJSON_String &= "," & $sObjDelEl
					Next
					$sJSON_String = StringTrimRight($sJSON_String, StringLen("," & $sObjDelEl)) & $sObjDelEl & $aObjIndCache[$iLevel] & "}"
				EndIf
			EndIf
		Case "Map"
			If UBound($oObject) = 0 Then
				$sJSON_String &= "{}"
			Else
				$sJSON_String &= "{" & $sObjDelEl
				For $sKey In MapKeys($oObject)
					$sKeyTemp = $sKey
					$oValue = $oObject[$sKey]

					$sJSON_String &= $aObjIndCache[$iLevel + 1] & '"' & __JSON_FormatString($sKeyTemp) & '"' & $sObjDelKey & ':' & $sObjDelVal

					_JSON_Generate($oValue, $sObjIndent, $sObjDelEl, $sObjDelKey, $sObjDelVal, $sArrIndent, $sArrDelEl, $iLevel + 1)

					$sJSON_String &= "," & $sObjDelEl
				Next
				$sJSON_String = StringTrimRight($sJSON_String, StringLen("," & $sObjDelEl)) & $sObjDelEl & $aObjIndCache[$iLevel] & "}"
			EndIf
		Case "Ptr"
			$sJSON_String &= String(Int($oObject))
		Case "DLLStruct"
			Local $tBin = DllStructCreate("Byte[" & DllStructGetSize($oObject) & "]", DllStructGetPtr($oObject))
			$sJSON_String &= '"' & __JSON_Base64Encode(DllStructGetData($tBin, 1)) & '"'
	EndSwitch

	If $iLevel = 0 Then
		Local $sTemp = $sJSON_String
		$sJSON_String = ""

		; clear indent cache:
		Redim $aObjIndCache[0]
		Redim $aArrIndCache[0]

		Return $sTemp
	EndIf
EndFunc   ;==>_JSON_Generate

; #FUNCTION# ====================================================================================================================
; Name ..........: _JSON_GenerateCompact
; Description ...: shorthand for _JSON_Generate()-parameters to produce a compact as possible JSON string
; Syntax ........: _JSON_GenerateCompact($oObject)
; Parameters ....: $oObject            - [nested] AutoIt data structure
; Return values .: Success - Return a JSON formatted string
;                  Failure - Return ""
; Author ........: AspirinJunkie
; Modified ......: 2023-05-23
; Related .......: _JSON_Generate
; ===============================================================================================================================
Func _JSON_GenerateCompact($oObject)
	Return _JSON_Generate($oObject, "", "", "", "", "", "")
EndFunc   ;==>_JSON_GenerateCompact

; #FUNCTION# ====================================================================================================================
; Name ..........: _JSON_Unminify
; Description ...: reads minified (compact) JSON file or string and converts to well readable JSON string
; Syntax ........: _JSON_Unminify($sInput)
; Parameters ....: $sInput - json file path/handle or json string
; Return values .: Success - Return a JSON formatted string
;                  Failure - Return "" and set @error to:
;                       @error = 1 - error during FileRead() - @extended = @error from FileRead()
;                              = 2 - no valid format for $sInput
; Author ........: Sven Seyfert (SOLVE-SMART), AspirinJunkie
; Related .......: _JSON_Generate
; ===============================================================================================================================
Func _JSON_Unminify($sInput)
	; read file if $sInput = file name or file handle
	If FileExists($sInput) Or IsInt($sInput) Then $sInput = FileRead($sInput)
	If @error Then Return SetError(1, @error, False)
	If Not IsString($sInput) Then Return SetError(2, 0, False)

	Local Const $oObject = _JSON_Parse($sInput)
	Return _JSON_Generate($oObject)
EndFunc   ;==>_JSON_Unminify

; #FUNCTION# ====================================================================================================================
; Name ..........: _JSON_Minify
; Description ...: reads unminified (readable) JSON file or string and converts to minified (compact) JSON string
; Syntax ........: _JSON_Minify($sInput)
; Parameters ....: $sInput - json file path/handle or json string
; Return values .: Success - Return a JSON formatted string
;                  Failure - Return "" and set @error to:
;                       @error = 1 - error during FileRead() - @extended = @error from FileRead()
;                              = 2 - no valid format for $sInput
; Author ........: Sven Seyfert (SOLVE-SMART), AspirinJunkie
; Related .......: _JSON_GenerateCompact
; ===============================================================================================================================
Func _JSON_Minify($sInput)
	; read file if $sInput = file name or file handle
	If FileExists($sInput) Or IsInt($sInput) Then $sInput = FileRead($sInput)
	If @error Then Return SetError(1, @error, False)
	If Not IsString($sInput) Then Return SetError(2, 0, False)

	Local Const $oObject = _JSON_Parse($sInput)
	Return _JSON_GenerateCompact($oObject)
EndFunc   ;==>_JSON_Minify

; #FUNCTION# ======================================================================================
; Name ..........: _JSON_Get
; Description ...: query nested AutoIt-datastructure with a simple query string with syntax:
;                  MapKey#1.MapKey#2.[ArrayIndex#1].MapKey#3... (points keynames can be achieved by "\.")
;                  multidimensional (2D or 3D only) array indices are separated through comma - e.g.: [2,3]
;                  negative array indices can be used: [-1] = last element, [-2] = second last element, ...
; Syntax ........: _JSON_Get(ByRef $oObject, Const $sPattern)
; Parameters ....: $oObject      - a nested AutoIt datastructure (Arrays, Dictionaries, basic scalar types)
;                  $sPattern     - query pattern like described above
; Return values .: Success - Return the queried object out of the nested datastructure
;                  Failure - Return Null and set @error to:
;                       @error = 1 - pattern is not correct
;                              = 2 - keyname query to none dictionary object
;                              = 3 - keyname queried not exists in dictionary
;                              = 4 - index query on none array object
;                              = 5 - index out of array range
;                              = 6 - number of subindices in index query not match array dimensions
;                              = 7 - more than 3 array dimensions are not supported
; Author ........: AspirinJunkie
; =================================================================================================
Func _JSON_Get(ByRef $oObject, Const $sPattern)
	Local $oCurrent = $oObject, $dVal
	Local $aTokens = StringRegExp($sPattern, '\[\h*(-?\d+(?>\h*,\h*-?\d+){0,2})\h*\]|((?>\\.|[^\.\[\]\\]+)+)', 4)
	If @error Then Return SetError(1, @error, Null)

	For $aCurToken In $aTokens
		If UBound($aCurToken) = 3 Then ; KeyName
			$aCurToken[2] = StringRegExpReplace($aCurToken[2], '\\(.)', '$1')
			Switch VarGetType($oCurrent)
				Case "Object"
					If Not IsObj($oCurrent) Or ObjName($oCurrent) <> "Dictionary" Then Return SetError(2, 0, Null)
					If Not $oCurrent.Exists($aCurToken[2]) Then Return SetError(3, 0, Null)

					$oCurrent = $oCurrent($aCurToken[2])
				Case "Map"
					If Not MapExists($oCurrent, $aCurToken[2]) Then Return SetError(3, 0, Null)

					$oCurrent = $oCurrent[$aCurToken[2]]
			EndSwitch
		ElseIf UBound($aCurToken) = 2 Then ; ArrayIndex
			If (Not IsArray($oCurrent)) Then Return SetError(4, UBound($oCurrent, 0), Null)

			; multi dimensional array
			If StringInStr($aCurToken[1], ',', 1) Then

				Local $aIndices = StringSplit($aCurToken[1], ',', 3)
				If UBound($aIndices) <> UBound($oCurrent, 0) Then Return SetError(6, UBound($oCurrent, 0), Null)

				; get the indices and check their range
				Local $x = Int($aIndices[0]), $y = Int($aIndices[1])

				; handle negative indices
				If $x < 0 Then $x += UBound($oCurrent, 1)
				If $y < 0 Then $y += UBound($oCurrent, 2)
				
				If $x < 0 Or $x >= UBound($oCurrent, 1) Then Return SetError(5, $x, Null)
				If $y < 0 Or $y >= UBound($oCurrent, 2) Then Return SetError(5, $y, Null)
				Switch UBound($aIndices)
					Case 2 ; 2D array
						$oCurrent = $oCurrent[$x][$y]
					Case 3 ; 3D array
						Local $z = Int($aIndices[2])
						If $z < 0 Then $z += UBound($oCurrent, 3)
						If $z < 0 Or $z >= UBound($oCurrent, 3) Then Return SetError(5, $z, Null)
						$oCurrent = $oCurrent[$x][$y][$z]
					Case Else
						Return SetError(7, @error, Null)
				EndSwitch

			; 1D array
			Else
				If UBound($oCurrent, 0) <> 1 Then Return SetError(6, UBound($oCurrent, 0), Null)
				$dVal = Int($aCurToken[1])
				If $dVal < 0 Then $dVal += UBound($oCurrent)
				If $dVal < 0 Or $dVal >= UBound($oCurrent) Then Return SetError(5, $dVal, Null)
				$oCurrent = $oCurrent[$dVal]
			EndIf
		EndIf
	Next
	Return $oCurrent
EndFunc   ;==>_JSON_Get


; #FUNCTION# ======================================================================================
; Name ..........: _JSON_addChangeDelete
; Description ...: creates, modifies or deletes within nested AutoIt structures with a simple query string with syntax:
;                  MapKey#1.MapKey#2.[ArrayIndex#1].MapKey#3...  (points keynames can be achieved by "\.")
;                  If the specified structure already exists, then the function overwrite the existing data.
;                  If the specified structure not exists, then the functions creates this structure.
;                  If $vVal = Default, then the function deletes this specific data point inside the structure.
;                  If ArrayIndex < 0: -1 means: append value to the array 
;                  If ArrayIndex < -1: relative to the end (-2 = last element, -3 = second last element, ...)
; Syntax ........: _JSON_addChangeDelete(ByRef $oObject, Const $sPattern, Const $vVal = Default [, Const $iRecLevel = 0])
; Parameters ....: $oObject    - a nested AutoIt datastructure (Arrays, Maps, basic scalar types etc.)
;                                in which the structure is to be created or data is to be changed or deleted
;                  $sPattern   - query pattern like described above
;                  $vVal       - the value which should be written at the position in $sPattern
;                              - if $vVal = Default then the position in $sPattern is to be deleted
;                  $iRecLevel  - don't touch! - only for internal purposes
; Return values .: Success - Return True
;                  Failure - Return False and set @error to:
;                       @error = 1 - pattern is not correct
;                       @error = 2 - wrong index for array element
; Author ........: AspirinJunkie
; =================================================================================================
Func _JSON_addChangeDelete(ByRef $oObject, Const $sPattern, Const $vVal = Default, Const $iRecLevel = 0)
	Local Static $aLevels[0]

	; only on highest recursion level: process the selector string
	If $iRecLevel = 0 Then
		Local $aToken = StringRegExp($sPattern, '\[(-?\d+)\]|((?>\\.|[^\.\[\]\\]+)+)', 4)
		If @error Then Return SetError(1, @error, "")

		Local $aCurToken

		ReDim $aLevels[UBound($aToken) + 1][2]
		For $i = 0 To UBound($aToken) - 1
			$aCurToken = $aToken[$i]
			If UBound($aCurToken) = 3 Then ; KeyName
				$aLevels[$i][0] = "Map"
				$aLevels[$i][1] = StringRegExpReplace($aCurToken[2], '\\(.)', '$1')
			Else ; Array Index
				$aLevels[$i][0] = "Array"
				$aLevels[$i][1] = Int($aCurToken[1])
			EndIf
		Next
		$aLevels[UBound($aLevels) - 1][0] = "end"
	EndIf

	; get current location
	Local $sCurrenttype  = $aLevels[$iRecLevel][0], _
	      $vCurrentIndex = $aLevels[$iRecLevel][1]

	; If data structure not exists already - build it as stated in the selector string:
	If $sCurrenttype <> VarGetType($oObject) Then
		Switch $sCurrenttype
			Case "Map"
				Local $mTmp[]
				$oObject = $mTmp
			Case "Array"
				Local $aTmp[($vCurrentIndex < -1 ? 0 : $vCurrentIndex) + 1]
				$oObject = $aTmp
			Case "end"
				Return $vVal
		EndSwitch
	EndIf

	; special case treatment for arrays
	If $sCurrenttype = "Array" Then
		; index "-1" means: append value to array
		; index < -1 means: index relative to the end (-2 = last element, -3 = second last element, ...)
		If $vCurrentIndex < 0 Then $vCurrentIndex = ($vCurrentIndex = -1) ? UBound($oObject) : Mod(Mod($vCurrentIndex + 1, UBound($oObject)) + UBound($oObject), UBound($oObject))  

		If UBound($oObject, 0) <> 1 Then
			Local $aTmp[$vCurrentIndex + 1]
			$oObject = $aTmp
		ElseIf UBound($oObject) < ($vCurrentIndex + 1) Then
			ReDim $oObject[$vCurrentIndex + 1]
		EndIf
	EndIf

	; create or change the objects in the next hierarchical level and use these as value for the current entry
	Local $vTmp = $oObject[$vCurrentIndex], _
			$oNext = _JSON_addChangeDelete($vTmp, $sPattern, $vVal, $iRecLevel + 1)

	If $oNext = Default Then ; delete the current level
		Switch $sCurrenttype
			Case "Map"
				MapRemove($oObject, $vCurrentIndex)
			Case "Array"
				Local $iInd = $vCurrentIndex, $nElems = UBound($oObject)

				If $iInd < 0 Or $iInd >= $nElems Then Return SetError(2, @error, "")

				For $i = $iInd To $nElems - 2
					$oObject[$i] = $oObject[$i + 1]
				Next
				ReDim $oObject[$nElems - 1]
			Case Else
				$oObject[$vCurrentIndex] = ""
				For $j = UBound($oObject) - 1 To 0 Step -1
					If $oObject[$j] <> "" Then
						ReDim $oObject[$j + 1]
						ExitLoop
					EndIf
				Next
		EndSwitch
	Else
		$oObject[$vCurrentIndex] = $oNext
	EndIf

	If $iRecLevel > 0 Then
		Return $oObject
	Else
		ReDim $aLevels[0] ; clean
		Return True
	EndIf
EndFunc   ;==>_JSON_addChangeDelete

; helper function for converting a json formatted string into an AutoIt-string
Func __JSON_ParseString($sString)
	Local $cChar, $mChars[]

	Local $aRE = StringRegExp($sString, '\\\\(*SKIP)(*F)|\\(u[[:xdigit:]]{4}|[^nrt\\])', 3)
	If Not @error Then
		For $cChar In $aRE
			; prevent double processing of already processed chars
			If MapExists($mChars, $cChar) Then ContinueLoop

			Switch StringLeft($cChar, 1)
				Case "b"
					$sString = StringRegExpReplace($sString, '\\\\(*SKIP)(*F)|\\b', Chr(8))
					$mChars[$cChar] = ""
				Case "f"
					$sString = StringRegExpReplace($sString, '\\\\(*SKIP)(*F)|\\f', Chr(12))
					$mChars[$cChar] = ""
				Case "u"
					$sString = StringRegExpReplace($sString, '\\\\(*SKIP)(*F)|\\' & $cChar, ChrW(Dec(StringTrimLeft($cChar, 1))))
					$mChars[$cChar] = ""
				Case Else
					$sString = StringRegExpReplace($sString, '\\\\(*SKIP)(*F)|\\\Q' & $cChar & '\E', $cChar)
					$mChars[$cChar] = ""
			EndSwitch
		Next
	EndIf

	; convert \n \r \t \\
	Return StringFormat(StringReplace($sString, "%", "%%", 0, 1))
EndFunc   ;==>__JSON_ParseString


; helper function for converting a AutoIt-string into a json formatted string
Func __JSON_FormatString($sString)
    ; Quick check if any characters need escaping
    If Not StringRegExp($sString, '[\n\r\t"\\\b\f]') Then Return $sString
    
    ; Special chars found - choose replacement method by string length:
    ; for small strings direct RegExpReplace-method is faster; for long strings the manual method is better
	Return StringLen($sString) < 50 _
	? StringTrimRight(StringRegExpReplace($sString & '\\\b\f\n\r\t\"', '(?s)(?|\\(?=.*(\\\\))|[\b](?=.*(\\b))|\f(?=.*(\\f))|\r\n(?=.*(\\n))|\n(?=.*(\\n))|\r(?=.*(\\r))|\t(?=.*(\\t))|"(?=.*(\\")))', '\1'), 15) _
	: StringReplace( _
		StringReplace( _
			StringReplace( _
				StringReplace( _
					StringReplace( _
						StringReplace( _
							StringReplace( _
								StringReplace($sString, '\', '\\', 0, 1) _
							, Chr(8), "\b", 0, 1) _
						, Chr(12), "\f", 0, 1) _
					, @CRLF, "\n", 0, 1) _
				, @LF, "\n", 0, 1) _
			, @CR, "\r", 0, 1) _
		, @TAB, "\t", 0, 1) _
	, '"', '\"', 0, 1)
EndFunc


; #FUNCTION# ======================================================================================
; Name ..........: __JSON_Base64Encode
; Description ...: convert a binary- or string-Input into BASE64 (or optional base64url) format
;                  mainly a wrapper for the CryptBinaryToString API-function
; Syntax ........: __JSON_Base64Encode(Const $sInput, [Const $b_base64url = False])
; Parameters ....: $sInput       - binary data or string which should be converted
;                  [$b_base64url] - If true the output is in base64url-format instead of base64
; Return values .: Success - Return base64 (or base64url) formatted string
;                  Failure - Return "" and set @error to:
;                       @error = 1 - failure at the first run to calculate the output size
;                              = 2 - failure at the second run to calculate the output
; Author ........: AspirinJunkie
; Example .......: Yes
;                  $sBase64String = __JSON_Base64Encode("This is my test")
; =================================================================================================
Func __JSON_Base64Encode(Const $sInput, Const $b_base64url = False)
	Local $b_Input = IsBinary($sInput) ? $sInput : Binary($sInput)

	Local $t_BinArray = DllStructCreate("BYTE[" & BinaryLen($sInput) & "]")
	DllStructSetData($t_BinArray, 1, $b_Input)

	Local $h_DLL_Crypt32 = DllOpen("Crypt32.dll")

	; first run to calculate needed size of output buffer
	Local $aRet = DllCall($h_DLL_Crypt32, "BOOLEAN", "CryptBinaryToString", _
			"STRUCT*", $t_BinArray, _     ; *pbBinary
			"DWORD", DllStructGetSize($t_BinArray), _     ; cbBinary
			"DWORD", 0x40000001, _     ; dwFlags
			"PTR", Null, _ ; pszString
			"DWORD*", 0)
	If @error Or Not IsArray($aRet) Or $aRet[0] = 0 Then Return SetError(1, @error, DllClose($h_DLL_Crypt32))

	; second run to calculate base64-string:
	Local $t_Output = DllStructCreate("CHAR Out[" & $aRet[5] & "]")
	Local $aRet2 = DllCall($h_DLL_Crypt32, "BOOLEAN", "CryptBinaryToString", _
			"STRUCT*", $t_BinArray, _     ; *pbBinary
			"DWORD", DllStructGetSize($t_BinArray), _     ; cbBinary
			"DWORD", 0x40000001, _     ; dwFlags
			"STRUCT*", $t_Output, _ ; pszString
			"DWORD*", $aRet[5])
	If @error Or Not IsArray($aRet2) Or $aRet2[0] = 0 Then Return SetError(2, @error, DllClose($h_DLL_Crypt32))

	Local $sOutput = $t_Output.Out
	If StringInStr($sOutput, "=", 1, 1) Then $sOutput = StringLeft($sOutput, StringInStr($sOutput, "=", 1, 1) - 1)

	If $b_base64url Then $sOutput = StringReplace(StringReplace($sOutput, "/", "_", 0, 1), "+", "-", 0, 1)

	DllClose($h_DLL_Crypt32)
	Return $sOutput
EndFunc   ;==>__JSON_Base64Encode


; #FUNCTION# ======================================================================================
; Name ..........: __JSON_Base64Decode
; Description ...: decode data which is coded as a base64-string into binary form
;                  mainly a wrapper for the CryptStringToBinary API-function
; Syntax ........: __JSON_Base64Decode(Const $sInput, [Const $b_base64url = False])
; Parameters ....: $sInput       - string in base64-format
;                  [$b_base64url] - If true the output is in base64url-format instead of base64
; Return values .: Success - Return base64 (or base64url) formatted string
;                  Failure - Return "" and set @error to:
;                       @error = 1 - failure at the first run to calculate the output size
;                              = 2 - failure at the second run to calculate the output
; Author ........: AspirinJunkie
; Example .......: Yes
;                  MsgBox(0, '', BinaryToString(__JSON_Base64Decode("VGVzdA")))
; =================================================================================================
Func __JSON_Base64Decode(Const $sInput, Const $b_base64url = False)
	Local $h_DLL_Crypt32 = DllOpen("Crypt32.dll")

	; first run to calculate needed size of output buffer
	Local $aRet = DllCall($h_DLL_Crypt32, "BOOLEAN", "CryptStringToBinary", _
			"STR", $sInput, _ ; pszString
			"DWORD", 0, _ ; cchString
			"DWORD", 1, _ ; dwFlags
			"PTR", Null, _ ; pbBinary
			"DWORD*", 0, _ ; pcbBinary
			"PTR", Null, _ ; pdwSkip
			"PTR", Null) ; pdwFlags
	Local $t_Ret = DllStructCreate("BYTE Out[" & $aRet[5] & "]")
	If @error Or Not IsArray($aRet) Or $aRet[0] = 0 Then Return SetError(1, @error, DllClose($h_DLL_Crypt32))


	; second run to calculate the output data:
	Local $aRet2 = DllCall($h_DLL_Crypt32, "BOOLEAN", "CryptStringToBinary", _
			"STR", $sInput, _ ; pszString
			"DWORD", 0, _ ; cchString
			"DWORD", 1, _ ; dwFlags
			"STRUCT*", $t_Ret, _ ; pbBinary
			"DWORD*", $aRet[5], _ ; pcbBinary
			"PTR", Null, _ ; pdwSkip
			"PTR", Null) ; pdwFlags
	If @error Or Not IsArray($aRet2) Or $aRet2[0] = 0 Then Return SetError(2, @error, DllClose($h_DLL_Crypt32))
	DllClose($h_DLL_Crypt32)

	Local $sOutput = $t_Ret.Out
	If $b_base64url Then $sOutput = StringReplace(StringReplace($sOutput, "_", "/", 0, 1), "-", "+", 0, 1)

	Return $sOutput
EndFunc   ;==>__JSON_Base64Decode

; #FUNCTION# ======================================================================================
; Name ..........: __JSON_A2DToAinA()
; Description ...: Convert a 2D array into a Arrays in Array
; Syntax ........: __JSON_A2DToAinA($A)
; Parameters ....: $A             - the 2D-Array  which should be converted
; Return values .: Success: a Arrays in Array build from the input array
;                  Failure: False
;                     @error = 1: $A is'nt an 2D array
; Author ........: AspirinJunkie
; Example .......: Yes
;                  #include <Array.au3>
;                  
;                  Global $a2DArray[][] = [[1,2,3],[4,5,6],[7,8,9],[10,11,12]]
;                  
;                  For $aRow In __JSON_A2DToAinA($a2DArray)
;                     _ArrayDisplay($aRow, "single rows as 1D-Arrays")
;                  Next
; =================================================================================================#
Func __JSON_A2DToAinA($A, $bTruncEmpty = True)
	If UBound($A, 0) <> 2 Then Return SetError(1, UBound($A, 0), False)
	Local $N = UBound($A), $u = UBound($A, 2)
	Local $aRet[$N]

	If $bTruncEmpty Then
		For $i = 0 To $N - 1
			Local $x = $u - 1
			While IsString($A[$i][$x]) And $A[$i][$x] = ""
				$x -= 1
			WEnd
			Local $t[$x + 1]
			For $j = 0 To $x
				$t[$j] = $A[$i][$j]
			Next
			$aRet[$i] = $t
		Next
	Else
		For $i = 0 To $N - 1
			Local $t[$u]
			For $j = 0 To $u - 1
				$t[$j] = $A[$i][$j]
			Next
			$aRet[$i] = $t
		Next
	EndIf
	Return $aRet
EndFunc   ;==>__JSON_A2DToAinA

; #FUNCTION# ======================================================================================
; Name ..........: __JSON_AinAToA2d()
; Description ...: Convert a Arrays in Array into a 2D array
;                  here useful if you want to recover 2D-arrays from a json-string
;                  (there exists only a array-in-array and no 2D-Arrays)
; Syntax ........: __JSON_AinAToA2d($A)
; Parameters ....: $A             - the arrays in array which should be converted
; Return values .: Success: a 2D Array build from the input array
;                  Failure: False
;                     @error = 1: $A is'nt an 1D array
;                            = 2: $A is empty
;                            = 3: first element isn't a array
; Author ........: AspirinJunkie
; =================================================================================================
Func __JSON_AinAToA2d($A)
	If UBound($A, 0) <> 1 Then Return SetError(1, UBound($A, 0), False)
	Local $N = UBound($A)
	If $N < 1 Then Return SetError(2, $N, False)
	Local $u = UBound($A[0])
	If $u < 1 Then Return SetError(3, $u, False)

	Local $aRet[$N][$u]

	For $i = 0 To $N - 1
		Local $t = $A[$i]
		If UBound($t) > $u Then ReDim $aRet[$N][UBound($t)]
		For $j = 0 To UBound($t) - 1
			$aRet[$i][$j] = $t[$j]
		Next
	Next
	Return $aRet
EndFunc   ;==>__JSON_AinAToA2d
