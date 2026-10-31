package top.izuna.foliamajor;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.FileVisitResult;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.Set;

// Installation-only filesystem cleanup and nonempty startup failure descriptions.
final class FoliaRuntimeFiles {
    private FoliaRuntimeFiles() {}

    static boolean isInstallation(File entry) {
        return entry.getName().matches("runtime-[0-9]+\\.[0-9]+\\.[0-9]+(?:-[A-Za-z0-9.-]+)?-[0-9]{13}");
    }

    // Walk without following symlinks or retaining every installed path in memory.
    static void removeTree(File directory) throws IOException {
        Path root = directory.toPath();
        if (!Files.exists(root, java.nio.file.LinkOption.NOFOLLOW_LINKS)) return;
        Files.walkFileTree(root, new SimpleFileVisitor<Path>() {
            @Override public FileVisitResult visitFile(Path file, BasicFileAttributes attributes) throws IOException {
                Files.delete(file);
                return FileVisitResult.CONTINUE;
            }
            @Override public FileVisitResult postVisitDirectory(Path folder, IOException failure) throws IOException {
                if (failure != null) throw failure;
                Files.delete(folder);
                return FileVisitResult.CONTINUE;
            }
        });
    }

    static String describe(Throwable failure) {
        StringBuilder result = new StringBuilder();
        Set<Throwable> seen = Collections.newSetFromMap(new IdentityHashMap<Throwable, Boolean>());
        for (Throwable current = failure; current != null && seen.add(current); current = current.getCause()) {
            if (result.length() > 0) result.append(" <- ");
            result.append(current.getClass().getSimpleName());
            String message = current.getMessage();
            if (message != null && !message.trim().isEmpty()) result.append(": ").append(message);
        }
        return result.length() > 0 ? result.toString() : "Unknown startup failure";
    }
}
