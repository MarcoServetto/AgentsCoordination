package mainController;

import java.nio.file.Path;

public class LocalResources {
  private static Path prefix= Path.of("/").resolve("data","fearlessBranch2");

  static public final Path commons= prefix.resolve("Commons");
  static public final Path frontend= prefix.resolve("Frontend","FearlessFrontend");
  static public final Path coordinator= prefix.resolve("Coordinator");
  static public final Path controller= prefix.resolve("EclipsePlugin");
  static public final Path stLib= prefix.resolve("StandardLibrary");
  static public final Path managedFolderOut= prefix.resolve("StandardLibrary","fearlessManagedArtefact");
}