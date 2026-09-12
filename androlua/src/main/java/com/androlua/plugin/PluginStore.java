package com.androlua.plugin;

import java.io.*;
import java.nio.ByteBuffer;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/** Private, versioned plugin storage. Preparing an import never executes plugin code. */
public final class PluginStore {
    public static final long MAX_ARCHIVE_BYTES = 32L * 1024 * 1024;
    public static final long MAX_EXPANDED_BYTES = 64L * 1024 * 1024;
    public static final long MAX_FILE_BYTES = 32L * 1024 * 1024;
    public static final int MAX_ENTRIES = 1024;
    private static final Object LOCK = new Object();
    private final File root;
    private final ManifestReader manifestReader;

    public interface ManifestReader {
        Metadata read(String json, Metadata defaults) throws IOException;
    }

    public static final class Metadata {
        public final String id, name, version, description;
        public Metadata(String id, String name, String version, String description) throws IOException {
            if (id == null || !id.matches("[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}"))
                throw new IOException("插件 ID 只能包含字母、数字、点、下划线和短横线，最多 64 字符");
            this.id = id;
            this.name = checkedText(name, 100, "名称", false);
            this.version = checkedText(version, 64, "版本", false);
            this.description = checkedText(description, 2000, "说明", true);
        }
    }

    public static final class Candidate implements Closeable {
        public final Metadata metadata;
        public final File directory;
        public final int fileCount;
        public final long bytes;
        public final boolean hasNativeCode;
        private boolean installed;
        private Candidate(Metadata metadata, File directory, int fileCount, long bytes, boolean nativeCode) {
            this.metadata = metadata; this.directory = directory;
            this.fileCount = fileCount; this.bytes = bytes; this.hasNativeCode = nativeCode;
        }
        public File getCodeDirectory() { return new File(directory, "payload"); }
        @Override public void close() { if (!installed) deleteTree(directory); }
    }

    public static final class Installed {
        public final Metadata metadata;
        public final boolean enabled;
        public final File directory;
        private final String revision;
        private Installed(Metadata metadata, boolean enabled, File directory, String revision) {
            this.metadata = metadata; this.enabled = enabled; this.directory = directory; this.revision = revision;
        }
        public File getCodeDirectory() { return new File(directory, "revisions/" + revision + "/payload"); }
        public File getEntryPoint() { return new File(getCodeDirectory(), "main.lua"); }
    }

    public PluginStore(File root, ManifestReader manifestReader) throws IOException {
        this.root = root.getCanonicalFile();
        this.manifestReader = manifestReader;
        mkdir(this.root);
    }

    public Candidate prepare(InputStream input, String displayName) throws IOException {
        if (displayName == null) throw new IOException("无法识别文件名，请选择 .lua、.zip 或 .alp 文件");
        String lower = displayName.toLowerCase(Locale.ROOT);
        boolean script = lower.endsWith(".lua");
        if (!script && !lower.endsWith(".zip") && !lower.endsWith(".alp"))
            throw new IOException("仅支持 .lua、.zip 和 .alp 文件");
        File stage = new File(root, ".staging-" + UUID.randomUUID());
        mkdir(stage);
        try {
            File payload = new File(stage, "payload");
            int files = 0;
            long size = 0;
            if (script) {
                mkdir(payload);
                try (OutputStream out = new FileOutputStream(new File(payload, "main.lua"))) {
                    size = copyLimited(input, out, MAX_FILE_BYTES);
                }
                files = 1;
            } else {
                File archive = new File(stage, "archive");
                mkdir(archive);
                Set<String> names = new HashSet<>();
                int entries = 0;
                try (ZipInputStream zip = new ZipInputStream(new LimitedInputStream(input, MAX_ARCHIVE_BYTES))) {
                    ZipEntry entry;
                    while ((entry = zip.getNextEntry()) != null) {
                        if (++entries > MAX_ENTRIES) throw new IOException("压缩包文件数量超过 1024");
                        String name = checkedArchivePath(entry.getName());
                        if (!names.add(name)) throw new IOException("压缩包含重复路径：" + name);
                        File output = new File(archive, name);
                        if (!output.getCanonicalPath().startsWith(archive.getCanonicalPath() + File.separator))
                            throw new IOException("压缩包路径越界");
                        if (entry.isDirectory()) { mkdir(output); continue; }
                        mkdir(output.getParentFile());
                        long remaining = Math.min(MAX_FILE_BYTES, MAX_EXPANDED_BYTES - size);
                        if (entry.getSize() > remaining) throw new IOException("压缩包展开后超过大小限制");
                        try (OutputStream out = new FileOutputStream(output)) {
                            size += copyLimited(zip, out, remaining);
                        }
                        files++;
                        zip.closeEntry();
                    }
                }
                File code = archive;
                if (!new File(code, "main.lua").isFile()) {
                    File[] children = archive.listFiles();
                    if (children == null || children.length != 1 || !children[0].isDirectory())
                        throw new IOException("压缩包根目录或唯一顶层文件夹必须包含 main.lua");
                    code = children[0];
                }
                if (!new File(code, "main.lua").isFile()) throw new IOException("插件缺少 main.lua");
                if (!code.renameTo(payload)) throw new IOException("无法准备插件目录");
                deleteTree(archive);
            }
            boolean nativeCode = validateFiles(payload);
            String stem = displayName.substring(0, displayName.lastIndexOf('.'));
            if (stem.isEmpty()) stem = "Lua 插件";
            if (stem.length() > 100) stem = stem.substring(0, 100);
            Metadata defaults = new Metadata("local-" + sha256(displayName.getBytes(StandardCharsets.UTF_8)).substring(0, 20), stem, "1.0", "");
            File manifest = new File(payload, "plugin.json");
            Metadata metadata = defaults;
            if (manifest.exists()) {
                if (!manifest.isFile() || manifest.length() > 16384) throw new IOException("plugin.json 超过 16 KB 或格式不正确");
                if (manifestReader == null) throw new IOException("当前环境无法读取 plugin.json");
                metadata = manifestReader.read(readUtf8(manifest), defaults);
                if (metadata == null) throw new IOException("plugin.json 内容不正确");
            }
            return new Candidate(metadata, stage, files, size, nativeCode);
        } catch (IOException | RuntimeException error) {
            deleteTree(stage);
            throw error;
        }
    }

    public List<Installed> list() throws IOException {
        synchronized (LOCK) {
            ArrayList<Installed> result = new ArrayList<>();
            File[] directories = root.listFiles();
            if (directories == null) throw new IOException("无法读取插件目录");
            for (File directory : directories) {
                if (directory.getName().startsWith(".") || !directory.isDirectory()) continue;
                Installed item = readInstalled(directory.getName());
                if (item != null) result.add(item);
            }
            Collections.sort(result, (a, b) -> a.metadata.name.compareToIgnoreCase(b.metadata.name));
            return result;
        }
    }

    public Installed find(String id) throws IOException {
        synchronized (LOCK) { return readInstalled(id); }
    }

    /** The caller must explicitly confirm a replacement after displaying both versions. */
    public Installed install(Candidate candidate, boolean replace) throws IOException {
        synchronized (LOCK) {
            if (candidate.installed || !candidate.directory.isDirectory()) throw new IOException("安装预览已失效，请重新导入");
            Installed previous = readInstalled(candidate.metadata.id);
            if (previous != null && !replace) throw new IOException("同 ID 插件已安装，需要确认更新");
            String revision = UUID.randomUUID().toString();
            File directory = new File(root, candidate.metadata.id);
            File revisions = new File(directory, "revisions");
            mkdir(revisions);
            File destination = new File(revisions, revision);
            if (!candidate.directory.renameTo(destination)) throw new IOException("无法保存插件");
            Installed installed = new Installed(candidate.metadata, previous == null || previous.enabled, directory, revision);
            try {
                writeState(installed);
                candidate.installed = true;
                return installed;
            } catch (IOException error) {
                deleteTree(destination);
                throw error;
            }
        }
    }

    public void setEnabled(String id, boolean enabled) throws IOException {
        synchronized (LOCK) {
            Installed installed = requireInstalled(id);
            writeState(new Installed(installed.metadata, enabled, installed.directory, installed.revision));
        }
    }

    public File entryPoint(String id) throws IOException {
        synchronized (LOCK) {
            Installed installed = requireInstalled(id);
            if (!installed.enabled) throw new IOException("此插件已停用，请先启用");
            return installed.getEntryPoint();
        }
    }

    public void uninstall(String id) throws IOException {
        synchronized (LOCK) {
            Installed installed = requireInstalled(id);
            File trash = new File(root, ".trash-" + UUID.randomUUID());
            if (!installed.directory.renameTo(trash)) throw new IOException("无法卸载插件");
            if (!deleteTree(trash)) throw new IOException("插件已移除，部分文件未能清理");
        }
    }

    private Installed requireInstalled(String id) throws IOException {
        Installed installed = readInstalled(id);
        if (installed == null) throw new IOException("插件已不存在，请刷新列表");
        return installed;
    }

    private Installed readInstalled(String id) throws IOException {
        if (!id.matches("[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}")) throw new IOException("无效插件 ID");
        File directory = new File(root, id);
        File state = new File(directory, "state.properties");
        if (!state.isFile()) return null;
        Properties properties = new Properties();
        try (InputStream in = new FileInputStream(state)) { properties.load(in); }
        String revision = properties.getProperty("revision", "");
        if (!revision.matches("[a-f0-9-]{36}")) throw new IOException("插件版本记录损坏：" + id);
        Metadata metadata = new Metadata(id, properties.getProperty("name"), properties.getProperty("version"), properties.getProperty("description", ""));
        Installed installed = new Installed(metadata, Boolean.parseBoolean(properties.getProperty("enabled", "false")), directory, revision);
        if (!installed.getEntryPoint().isFile()) throw new IOException("插件入口文件丢失：" + id);
        return installed;
    }

    private void writeState(Installed installed) throws IOException {
        Properties properties = new Properties();
        properties.setProperty("name", installed.metadata.name);
        properties.setProperty("version", installed.metadata.version);
        properties.setProperty("description", installed.metadata.description);
        properties.setProperty("revision", installed.revision);
        properties.setProperty("enabled", Boolean.toString(installed.enabled));
        File temporary = new File(installed.directory, ".state-" + UUID.randomUUID());
        try {
            try (FileOutputStream out = new FileOutputStream(temporary)) {
                properties.store(out, "RXboxes plugin");
                out.getFD().sync();
            }
            if (!temporary.renameTo(new File(installed.directory, "state.properties")))
                throw new IOException("无法保存插件状态");
        } finally { temporary.delete(); }
    }

    private static boolean validateFiles(File directory) throws IOException {
        boolean nativeCode = false;
        File[] files = directory.listFiles();
        if (files == null) throw new IOException("无法读取插件文件");
        for (File file : files) {
            if (file.isDirectory()) { nativeCode |= validateFiles(file); continue; }
            String lower = file.getName().toLowerCase(Locale.ROOT);
            if (lower.endsWith(".luac")) throw new IOException("不支持外部 Lua 字节码，请提供 UTF-8 Lua 源码");
            if (lower.endsWith(".lua") || lower.endsWith(".aly")) {
                String source = readUtf8(file);
                if (source.indexOf('\0') >= 0 || source.indexOf('\u001b') >= 0)
                    throw new IOException("Lua 文件包含字节码或无效字符：" + file.getName());
            }
            if (lower.endsWith(".so")) {
                byte[] header = new byte[20];
                try (DataInputStream in = new DataInputStream(new FileInputStream(file))) { in.readFully(header); }
                if (header[0] != 0x7f || header[1] != 'E' || header[2] != 'L' || header[3] != 'F'
                        || header[4] != 2 || header[5] != 1 || (header[18] & 255) != 183 || header[19] != 0)
                    throw new IOException("原生扩展必须为 Android arm64-v8a ELF：" + file.getName());
                nativeCode = true;
            }
            if (lower.endsWith(".dex") || lower.endsWith(".jar") || lower.endsWith(".apk")) nativeCode = true;
        }
        return nativeCode;
    }

    private static String readUtf8(File file) throws IOException {
        if (file.length() > MAX_FILE_BYTES) throw new IOException("文件超过大小限制");
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (InputStream in = new FileInputStream(file)) { copyLimited(in, out, MAX_FILE_BYTES); }
        try {
            return StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(out.toByteArray())).toString();
        } catch (java.nio.charset.CharacterCodingException error) {
            throw new IOException("文本文件必须使用 UTF-8 编码：" + file.getName(), error);
        }
    }

    private static String checkedArchivePath(String name) throws IOException {
        if (name == null || name.isEmpty() || name.length() > 240 || name.startsWith("/") || name.indexOf('\\') >= 0 || name.indexOf(':') >= 0 || name.indexOf('\0') >= 0)
            throw new IOException("压缩包包含非法路径");
        if (name.endsWith("/")) name = name.substring(0, name.length() - 1);
        for (String part : name.split("/", -1)) {
            if (part.isEmpty() || part.equals(".") || part.equals("..")) throw new IOException("压缩包包含非法路径：" + name);
        }
        return name;
    }

    private static String checkedText(String value, int limit, String label, boolean empty) throws IOException {
        if (value == null || value.length() > limit || (!empty && value.trim().isEmpty())) throw new IOException("插件" + label + "无效");
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            if ((c < 32 && c != '\n' && c != '\t') || c == 127) throw new IOException("插件" + label + "包含无效字符");
        }
        return value;
    }

    private static long copyLimited(InputStream in, OutputStream out, long limit) throws IOException {
        byte[] buffer = new byte[8192];
        long count = 0;
        int read;
        while ((read = in.read(buffer)) != -1) {
            count += read;
            if (count > limit) throw new IOException("插件文件超过大小限制");
            out.write(buffer, 0, read);
        }
        return count;
    }

    private static void mkdir(File file) throws IOException {
        if (!file.isDirectory() && !file.mkdirs()) throw new IOException("无法创建插件目录");
    }

    public static boolean deleteTree(File file) {
        boolean success = true;
        File[] children = file.listFiles();
        if (children != null) for (File child : children) success &= deleteTree(child);
        return (!file.exists() || file.delete()) && success;
    }

    public static String sha256(byte[] value) throws IOException {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value);
            StringBuilder result = new StringBuilder();
            for (byte b : digest) result.append(String.format(Locale.ROOT, "%02x", b & 255));
            return result.toString();
        } catch (java.security.NoSuchAlgorithmException error) { throw new IOException(error); }
    }

    private static final class LimitedInputStream extends FilterInputStream {
        private final long limit;
        private long count;
        LimitedInputStream(InputStream input, long limit) { super(input); this.limit = limit; }
        private void count(int size) throws IOException {
            if (size > 0 && (count += size) > limit) throw new IOException("压缩包超过 32 MB");
        }
        @Override public int read() throws IOException { int value = in.read(); count(value < 0 ? 0 : 1); return value; }
        @Override public int read(byte[] bytes, int offset, int length) throws IOException {
            int size = in.read(bytes, offset, length); count(size); return size;
        }
    }
}
