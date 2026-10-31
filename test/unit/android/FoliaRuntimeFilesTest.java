package top.izuna.foliamajor;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import javax.crypto.AEADBadTagException;

// Small JVM regression for installation cleanup boundaries and message-less startup errors.
public final class FoliaRuntimeFilesTest {
    private static void check(boolean condition, String label) {
        if (!condition) throw new AssertionError(label);
    }

    public static void main(String[] args) throws Exception {
        Path root = Files.createTempDirectory("folia-runtime-install-");
        try {
            check(FoliaRuntimeFiles.isInstallation(new File("runtime-0.7.20-mobile.12-1792850000000")), "versioned install");
            check(!FoliaRuntimeFiles.isInstallation(new File("runtime-data")), "persistent data excluded");
            check(!FoliaRuntimeFiles.isInstallation(new File("runtime-key")), "credentials excluded");
            check(!FoliaRuntimeFiles.isInstallation(new File("runtime-0.7.20-mobile.12-backup")), "unowned paths excluded");
            Path data = Files.createDirectory(root.resolve("runtime-data"));
            Path secret = Files.writeString(data.resolve("settings.json"), "preserved");
            Path incomplete = Files.createDirectories(root.resolve("runtime-0.7.20-mobile.12-1792850000000/usr/lib"));
            Files.writeString(incomplete.resolve("libexample.so"), "library").toFile().setReadOnly();
            Files.createSymbolicLink(incomplete.resolve("outside"), data);
            Files.createSymbolicLink(incomplete.resolve("broken"), root.resolve("not-present"));
            FoliaRuntimeFiles.removeTree(incomplete.getParent().getParent().toFile());
            check(!Files.exists(incomplete.getParent().getParent()), "incomplete installation removed without ready marker");
            check(Files.readString(secret).equals("preserved"), "symlink target and user data preserved");
            FoliaRuntimeFiles.removeTree(incomplete.getParent().getParent().toFile());
            check(FoliaRuntimeFiles.describe(new AEADBadTagException()).equals("AEADBadTagException"), "null crypto message retains type");
            check(FoliaRuntimeFiles.describe(new IOException("installation", new NullPointerException()))
                .equals("IOException: installation <- NullPointerException"), "nested null message retains cause");
            IOException first = new IOException();
            IOException second = new IOException(first);
            first.initCause(second);
            check(FoliaRuntimeFiles.describe(first).length() < 200, "cause cycle terminates");
            System.out.println("Runtime installation cleanup and startup error checks passed");
        } finally { FoliaRuntimeFiles.removeTree(root.toFile()); }
    }
}
