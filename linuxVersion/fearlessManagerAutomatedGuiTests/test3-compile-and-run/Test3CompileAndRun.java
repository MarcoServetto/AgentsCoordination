import agentTools.Pilot;
import utils.Err;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Objects;
import java.util.function.BooleanSupplier;
import java.util.regex.Pattern;

/// Auto-mode replay of fearlessManagerAutomatedGuiTests/allTests.txt TEST 3 "Compile and run",
/// recorded from a manual Pilot session logged at
/// overnightLogs/2026-09-13-gui-auto-harness/test3-manual-log.json on the machine that produced
/// the pixel coordinates below. It assumes the manager's data folder already has a project
/// named "hello_world" registered (as it does after any prior manual or auto run on this
/// machine) and that it is the only tile to the right of "gui_basics" in the icon grid: it does
/// not automate "Add folder", whose file-chooser needs vision to drive reliably.
/// Run: /opt/jdk-26.0.2/bin/java -ea --module-path <branch>/out/modular/mods/Commons.jar
///   --add-modules Commons -cp <branch>/out/modular/controller-test Test3CompileAndRun.java
///   [branchRoot]
public class Test3CompileAndRun{
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
    Err.setUp(AssertionError.class, Test3CompileAndRun::assertEquals, b->{ if (!b){ throw new AssertionError(); } });
    ensureManagerRunning();
    var pilot= new Pilot();
    pilot.click(264,183);
    Pilot.pause(500);
    if (field(readState(),"needsCompiling").equals("false")){
      pilot.click(159,79);
      Pilot.pause(300);
      pilot.click(172,128);
      waitFor(()->field(readState(),"needsCompiling").equals("true"),5000);
    }
    pilot.click(480,112);
    waitFor(()->field(readState(),"needsCompiling").equals("false"),8000);
    var runsBefore= Integer.parseInt(field(readState(),"runs"));
    pilot.click(431,165);
    Pilot.pause(300);
    pilot.click(480,112);
    waitFor(()->field(readState(),"running").isEmpty() && Integer.parseInt(field(readState(),"runs"))==runsBefore+5,15000);
    var state= readState();
    Err.strCmp("0",field(state,"exit"));
    Err.strCmp("hello.Hello6",field(state,"lastRun"));
    var console= Files.readString(consoleFile);
    var tail= console.substring(console.lastIndexOf("--- compiling 01_hello_world ---")).trim();
    Err.strCmp(expectedTail(),tail);
    System.out.println("TEST 3 Compile and run: PASS");
  }
  static String expectedTail(){
    return
      "--- compiling 01_hello_world ---\n"+
      "--- compile done ---\n"+
      "--- running hello.Hello1 ---\n"+
      "hello world 3\n"+
      "--- hello.Hello1 exited with 0 after [###]s ---\n"+
      "--- running hello.Hello3 ---\n"+
      "[Hi]\n"+
      "--- hello.Hello3 exited with 0 after [###]s ---\n"+
      "--- running hello.Hello4 ---\n"+
      "[1, 2, 3, 4]\n"+
      "--- hello.Hello4 exited with 0 after [###]s ---\n"+
      "--- running hello.Hello5 ---\n"+
      "[11, 12, 13, 14]\n"+
      "--- hello.Hello5 exited with 0 after [###]s ---\n"+
      "--- running hello.Hello6 ---\n"+
      "AAAAh\n"+
      "imm Bar.bar error line: 16 in file _hello/_rank_app.fear\n"+
      "imm Foo.foo error line: 15 in file _hello/_rank_app.fear\n"+
      "imm Hello6.main(_) error line: 14 in file _hello/_rank_app.fear\n"+
      "--- hello.Hello6 exited with 0 after [###]s ---";
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
