import agentTools.Pilot;
import utils.Err;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Objects;
import java.util.function.BooleanSupplier;
import java.util.regex.Pattern;

/// Auto-mode replay of fearlessManagerAutomatedGuiTests/allTests.txt TEST 9 "Recompile after
/// Clear cache", recorded from a manual Pilot session logged at
/// overnightLogs/2026-09-13-gui-auto-harness/test9-manual-log.json. It assumes the manager's
/// data folder already has a project named "hello_world" registered, as the sole or first
/// (alphabetically before "hello_world") tile is not required, only the fixed tile position
/// used below; it does not automate "Add folder".
/// Run: /opt/jdk-26.0.2/bin/java -ea --module-path <branch>/out/modular/mods/Commons.jar
///   --add-modules Commons -cp <branch>/out/modular/controller-test
///   Test9RecompileAfterClearCache.java [branchRoot]
public class Test9RecompileAfterClearCache{
  static Path branch;
  static Path managerData;
  static Path launcher;
  static Path stateFile;
  static Path consoleFile;
  public static void main(String[] args) throws Exception{
    branch= Path.of(args.length>0 ? args[0] : "/data/fearlessBranch3");
    managerData= branch.resolve("StandardLibrary/fearlessManagedArtefact/fearless0_001");
    launcher= branch.resolve("StandardLibrary/fearlessManagedArtefact/fearlessManaged0_001/bin/fearlessManaged0_001");
    stateFile= managerData.resolve("eclipse/hello_world/state.txt");
    consoleFile= managerData.resolve("eclipse/hello_world/console.txt");
    Err.setUp(AssertionError.class, Test9RecompileAfterClearCache::assertEquals, b->{ if (!b){ throw new AssertionError(); } });
    ensureManagerRunning();
    var pilot= new Pilot();
    pilot.click(264,183);
    Pilot.pause(500);
    if (field(readState(),"needsCompiling").equals("true")){
      pilot.click(480,112);
      waitFor(()->field(readState(),"needsCompiling").equals("false"),8000);
    }
    pilot.click(159,79);
    Pilot.pause(300);
    pilot.click(172,128);
    waitFor(()->field(readState(),"needsCompiling").equals("true"),5000);
    var afterClear= readState();
    Err.strCmp("true",field(afterClear,"needsCompiling"));
    if (!afterClear.contains("\"mains\": {}")){ throw new AssertionError("mains not cleared after Clear cache: "+afterClear); }
    var compileCountBefore= countOccurrences(Files.readString(consoleFile),"--- compile done ---");
    pilot.click(480,112);
    waitFor(()->field(readState(),"needsCompiling").equals("false"),8000);
    var state= readState();
    Err.strCmp("false",field(state,"needsCompiling"));
    for (var main: new String[]{"hello.Hello1","hello.Hello3","hello.Hello4","hello.Hello5","hello.Hello6"}){
      if (!state.contains("\""+main+"\"")){ throw new AssertionError("main "+main+" missing from state.txt mains after recompile: "+state); }
    }
    var compileCountAfter= countOccurrences(Files.readString(consoleFile),"--- compile done ---");
    if (compileCountAfter != compileCountBefore+1){ throw new AssertionError("expected exactly one new compile-done block, before="+compileCountBefore+" after="+compileCountAfter); }
    System.out.println("TEST 9 Recompile after Clear cache: PASS");
  }
  static int countOccurrences(String text, String needle){
    var n= 0;
    var i= 0;
    while ((i= text.indexOf(needle,i)) != -1){ n++; i+= needle.length(); }
    return n;
  }
  static void ensureManagerRunning() throws Exception{
    var running= new ProcessBuilder("pgrep","-f",launcher.toString()).start().waitFor() == 0;
    if (running){ return; }
    new ProcessBuilder(launcher.toString()).start();
    Pilot.pause(4000);
  }
  static String readState(){
    if (!Files.exists(stateFile)){ return "{}"; }
    try{ return Files.readString(stateFile); }
    catch(Exception e){ throw new RuntimeException(e); }
  }
  static String field(String json, String key){
    var m= Pattern.compile("\""+key+"\"\\s*:\\s*\"([^\"]*)\"").matcher(json);
    return m.find() ? m.group(1) : "";
  }
  static void waitFor(BooleanSupplier cond, int timeoutMs) throws InterruptedException{
    var deadline= System.currentTimeMillis()+timeoutMs;
    while (!cond.getAsBoolean()){
      if (System.currentTimeMillis()>deadline){ throw new AssertionError("timed out waiting for condition"); }
      Thread.sleep(200);
    }
  }
  static void assertEquals(String e, String a){ if (!Objects.equals(e,a)){ throw new AssertionError("expected <"+e+"> but was <"+a+">"); } }
}
