Sub Mastersolve()

Do
        Range("paste").Value = Range("copy").Value
        Application.Calculate
        
Loop Until Range("mastercheck").Value = 0


End Sub