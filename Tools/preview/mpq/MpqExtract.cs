using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;

// Read-only extractor for the MPQ v1/v2 archives of the 3.3.5a client. Only zlib
// sectors are supported; files compressed differently are reported, not guessed.
public static class MpqExtract
{
    static readonly uint[] Crypt = BuildCrypt();

    static uint[] BuildCrypt()
    {
        var table = new uint[0x500];
        uint seed = 0x00100001;
        for (int i = 0; i < 0x100; i++)
        {
            for (int j = 0, index = i; j < 5; j++, index += 0x100)
            {
                seed = (seed * 125 + 3) % 0x2AAAAB;
                uint high = (seed & 0xFFFF) << 16;
                seed = (seed * 125 + 3) % 0x2AAAAB;
                table[index] = high | (seed & 0xFFFF);
            }
        }
        return table;
    }

    static uint Hash(string text, uint type)
    {
        uint seed1 = 0x7FED7FED, seed2 = 0xEEEEEEEE;
        foreach (char raw in text.ToUpperInvariant())
        {
            uint ch = raw == '/' ? '\\' : raw;
            seed1 = Crypt[type * 0x100 + ch] ^ (seed1 + seed2);
            seed2 = ch + seed1 + seed2 + (seed2 << 5) + 3;
        }
        return seed1;
    }

    static void Decrypt(uint[] data, uint key)
    {
        uint seed2 = 0xEEEEEEEE;
        for (int i = 0; i < data.Length; i++)
        {
            seed2 += Crypt[0x400 + (key & 0xFF)];
            uint ch = data[i] ^ (key + seed2);
            key = ((~key << 0x15) + 0x11111111) | (key >> 0x0B);
            seed2 = ch + seed2 + (seed2 << 5) + 3;
            data[i] = ch;
        }
    }

    static void DecryptBytes(byte[] bytes, int length, uint key)
    {
        int words = length / 4;
        var data = new uint[words];
        Buffer.BlockCopy(bytes, 0, data, 0, words * 4);
        Decrypt(data, key);
        Buffer.BlockCopy(data, 0, bytes, 0, words * 4);
    }

    class Archive
    {
        public string Path;
        public FileStream Stream;
        public long Base;
        public int SectorSize;
        public uint[] HashTable;
        public uint[] BlockTable;
        public ushort[] BlockHi;
    }

    static uint[] ReadTable(BinaryReader reader, long offset, uint entries, string keyName)
    {
        reader.BaseStream.Seek(offset, SeekOrigin.Begin);
        var bytes = reader.ReadBytes((int)entries * 16);
        var table = new uint[entries * 4];
        Buffer.BlockCopy(bytes, 0, table, 0, bytes.Length);
        Decrypt(table, Hash(keyName, 3));
        return table;
    }

    static Archive Open(string path)
    {
        var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        var reader = new BinaryReader(stream);
        for (long offset = 0; offset < stream.Length; offset += 0x200)
        {
            stream.Seek(offset, SeekOrigin.Begin);
            if (reader.ReadUInt32() != 0x1A51504D) continue;
            reader.ReadUInt32();
            reader.ReadUInt32();
            ushort version = reader.ReadUInt16();
            ushort shift = reader.ReadUInt16();
            long hashPos = reader.ReadUInt32();
            long blockPos = reader.ReadUInt32();
            uint hashSize = reader.ReadUInt32();
            uint blockSize = reader.ReadUInt32();
            long hiBlockPos = 0;
            if (version >= 1)
            {
                hiBlockPos = reader.ReadInt64();
                hashPos |= (long)reader.ReadUInt16() << 32;
                blockPos |= (long)reader.ReadUInt16() << 32;
            }
            var archive = new Archive { Path = path, Stream = stream, Base = offset, SectorSize = 512 << shift };
            archive.HashTable = ReadTable(reader, offset + hashPos, hashSize, "(hash table)");
            archive.BlockTable = ReadTable(reader, offset + blockPos, blockSize, "(block table)");
            if (hiBlockPos != 0)
            {
                stream.Seek(offset + hiBlockPos, SeekOrigin.Begin);
                archive.BlockHi = new ushort[blockSize];
                for (int i = 0; i < blockSize; i++) archive.BlockHi[i] = reader.ReadUInt16();
            }
            return archive;
        }
        throw new InvalidDataException("no MPQ header: " + path);
    }

    static int Find(Archive archive, string name)
    {
        uint count = (uint)(archive.HashTable.Length / 4);
        uint index = Hash(name, 0) & (count - 1), a = Hash(name, 1), b = Hash(name, 2);
        for (uint step = 0; step < count; step++)
        {
            uint slot = ((index + step) & (count - 1)) * 4;
            uint block = archive.HashTable[slot + 3];
            if (block == 0xFFFFFFFF) return -1;
            if (archive.HashTable[slot] == a && archive.HashTable[slot + 1] == b && block != 0xFFFFFFFE) return (int)block;
        }
        return -1;
    }

    static byte[] Inflate(byte[] data, int offset, int length, int expected)
    {
        byte method = data[offset];
        if (method != 0x02) throw new NotSupportedException("compression 0x" + method.ToString("X2"));
        using (var input = new MemoryStream(data, offset + 3, length - 3))
        using (var deflate = new DeflateStream(input, CompressionMode.Decompress))
        {
            var output = new byte[expected];
            int read = 0;
            while (read < expected)
            {
                int n = deflate.Read(output, read, expected - read);
                if (n == 0) break;
                read += n;
            }
            return output;
        }
    }

    static byte[] Read(Archive archive, int blockIndex, string name)
    {
        uint[] block = archive.BlockTable;
        long position = block[blockIndex * 4];
        if (archive.BlockHi != null) position |= (long)archive.BlockHi[blockIndex] << 32;
        uint packed = block[blockIndex * 4 + 1], size = block[blockIndex * 4 + 2], flags = block[blockIndex * 4 + 3];
        if ((flags & 0x80000000) == 0) return null;
        if ((flags & 0x100) != 0) throw new NotSupportedException("imploded");
        var reader = new BinaryReader(archive.Stream);
        archive.Stream.Seek(archive.Base + position, SeekOrigin.Begin);
        byte[] raw = reader.ReadBytes((int)packed);
        bool encrypted = (flags & 0x10000) != 0;
        uint key = 0;
        if (encrypted)
        {
            string shortName = name.Substring(name.LastIndexOf('\\') + 1);
            key = Hash(shortName, 3);
            if ((flags & 0x20000) != 0) key = (key + (uint)position) ^ size;
        }
        bool compressed = (flags & 0x200) != 0;
        if ((flags & 0x01000000) != 0)
        {
            if (encrypted) DecryptBytes(raw, raw.Length, key);
            return compressed && packed < size ? Inflate(raw, 0, raw.Length, (int)size) : raw;
        }
        if (!compressed)
        {
            if (encrypted) throw new NotSupportedException("encrypted uncompressed");
            return raw;
        }
        int sectors = (int)((size + archive.SectorSize - 1) / archive.SectorSize);
        var offsets = new uint[sectors + 1];
        Buffer.BlockCopy(raw, 0, offsets, 0, offsets.Length * 4);
        if (encrypted) Decrypt(offsets, key - 1);
        var result = new byte[size];
        for (int i = 0; i < sectors; i++)
        {
            int start = (int)offsets[i], length = (int)(offsets[i + 1] - offsets[i]);
            int expected = (int)Math.Min(archive.SectorSize, size - (long)i * archive.SectorSize);
            var sector = new byte[length];
            Buffer.BlockCopy(raw, start, sector, 0, length);
            if (encrypted) DecryptBytes(sector, length, key + (uint)i);
            byte[] plain = length < expected ? Inflate(sector, 0, length, expected) : sector;
            Buffer.BlockCopy(plain, 0, result, i * archive.SectorSize, expected);
        }
        return result;
    }

    // archives: highest priority first. Returns "OK name", "MISSING name" or "ERROR name: reason" lines.
    public static string[] Run(string[] archives, string[] names, string outputDir)
    {
        var opened = new List<Archive>();
        foreach (var path in archives) if (File.Exists(path)) opened.Add(Open(path));
        var report = new List<string>();
        foreach (var raw in names)
        {
            string name = raw.Trim().Replace('/', '\\');
            if (name.Length == 0) continue;
            bool found = false;
            foreach (var archive in opened)
            {
                int block = Find(archive, name);
                if (block < 0) continue;
                found = true;
                try
                {
                    byte[] data = Read(archive, block, name);
                    if (data == null) { found = false; continue; }
                    string target = System.IO.Path.Combine(outputDir, name);
                    Directory.CreateDirectory(System.IO.Path.GetDirectoryName(target));
                    File.WriteAllBytes(target, data);
                    report.Add("OK " + name + " <" + System.IO.Path.GetFileName(archive.Path));
                }
                catch (Exception error) { report.Add("ERROR " + name + ": " + error.Message); }
                break;
            }
            if (!found) report.Add("MISSING " + name);
        }
        foreach (var archive in opened) archive.Stream.Dispose();
        return report.ToArray();
    }
}
