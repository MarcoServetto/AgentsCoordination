import agentTools.Pilot;
import utils.Err;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Objects;
import java.util.function.BooleanSupplier;
import java.util.regex.Pattern;

/// Auto-mode replay of fearlessManagerAutomatedGuiTests/allTests.txt TEST 5 "Running program
/// and Terminate", recorded from a manual Pilot session logged at
/// overnightLogs/2026-09-13-gui-auto-harness/test5-manual-log.json. It assumes the manager's
/// data folder already has a project named "gui_basics" registered, of kind code, at the tile
/// position used below (left of "hello_world" in an alphabetically sorted 2-tile grid); it does
/// not automate "Add folder". gui_basics's own main never exits on its own, so this test's whole
/// point is Terminate: a run that outlives this script without being terminated would leave a
/// live gui_example.Foo child process and an open desktop window behind.
/// Run: /opt/jdk-26.0.2/bin/java -ea --module-path <branch>/out/modular/mods/Commons.jar
///   --add-modules Commons -cp <branch>/out/modular/controller-test
///   Test5RunAndTerminate.java [branchRoot]
public class Test5RunAndTerminate{
  static Path branch;
  static Path managerData;
  static Path launcher;
  static Path stateFile;
  static Path consoleFile;
  public static void main(String[] args) throws Exception{
    branch= Path.of(args.length>0 ? args[0] : "/data/fearlessBranch3");
    managerData= branch.resolve("StandardLibrary/fearlessManagedArtefact/fearless0_001");
    launcher= branch.resolve("StandardLibrary/fearlessManagedArtefact/fearlessManaged0_001/bin/fearlessManaged0_001");
    stateFile= managerData.resolve("eclipse/gui_basics/state.txt");
    consoleFile= managerData.resolve("eclipse/gui_basics/console.txt");
    Err.setUp(AssertionError.class, Test5RunAndTerminate::assertEquals, b->{ if (!b){ throw new AssertionError(); } });
    ensureManagerRunning();
    var pilot= new Pilot();
    pilot.click(137,183);
    Pilot.pause(500);
    if (field(readState(),"needsCompiling").equals("true")){
      pilot.click(480,112);
      waitFor(()->field(readState(),"needsCompiling").equals("false"),8000);
    }
    var runsBefore= Integer.parseInt(field(readState(),"runs"));
    pilot.click(481,112);
    waitFor(()->field(readState(),"running").equals("gui_example.Foo"),8000);
    pilot.click(218,79);
    Pilot.pause(300);
    pilot.click(280,103);
    Pilot.pause(300);
    pilot.click(500,112);
    waitFor(()->field(readState(),"running").isEmpty() && Integer.parseInt(field(readState(),"runs"))==runsBefore+1,10000);
    var state= readState();
    Err.strCmp("143",field(state,"exit"));
    Err.strCmp("gui_example.Foo",field(state,"lastRun"));
    var console= Files.readString(consoleFile);
    var tail= console.substring(console.lastIndexOf("--- running gui_example.Foo ---")).trim();
    Err.strCmp(
      "--- running gui_example.Foo ---\n"+
      "--- terminating gui_example.Foo ---\n"+
      "--- gui_example.Foo exited with 143 after [###]s ---",
      tail);
    System.out.println("TEST 5 Running program and Terminate: PASS");
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
