@echo off
setlocal

if not "%JAVA_HOME%"=="" if exist "%JAVA_HOME%\bin\java.exe" (
  "%JAVA_HOME%\bin\java.exe" %*
  exit /b %ERRORLEVEL%
)

"C:\Program Files\Huawei\DevEco Studio\jbr\bin\java.exe" %*
exit /b %ERRORLEVEL%
