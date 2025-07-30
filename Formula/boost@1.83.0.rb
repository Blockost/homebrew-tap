class BoostAT1830 < Formula
  desc "Collection of portable C++ source libraries"
  homepage "https://www.boost.org/"
  url "https://github.com/boostorg/boost/releases/download/boost-1.83.0/boost-1.83.0.tar.xz"
  sha256 "c5a0688e1f0c05f354bbd0b32244d36085d9ffc9f932e8a18983a9908096f614"
  license "BSL-1.0"
  head "https://github.com/boostorg/boost.git", branch: "master"

  livecheck do
    url "https://www.boost.org/users/download/"
    regex(/href=.*?boost[._-]v?(\d+(?:[._]\d+)+)\.t/i)
    strategy :page_match do |page, regex|
      page.scan(regex).map { |match| match.first.tr("_", ".") }
    end
  end

  # Comment to trigger PR worflow
  bottle do
    root_url "https://github.com/Blockost/homebrew-tap/releases/download/boost@1.83.0-1.83.0"
    rebuild 1
    sha256 arm64_sequoia: "b8f768a9ac3ad2dd03d2a997c4c4665fac2afb626f7c4c7f4b4e8833886193e7"
    sha256 arm64_sonoma:  "d38cfb3054b30a479b2c2beba8dc828fc98aa7a308832b5e7f94b32fa9671484"
  end

  depends_on "icu4c"
  depends_on "xz"
  depends_on "zstd"

  uses_from_macos "bzip2"
  uses_from_macos "zlib"

  # fix for https://github.com/boostorg/process/issues/342
  # should eventually be in boost 1.84
  patch :DATA

  def install
    # Force boost to compile with the desired compiler
    open("user-config.jam", "a") do |file|
      if OS.mac?
        file.write "using darwin : : #{ENV.cxx} ;\n"
      else
        file.write "using gcc : : #{ENV.cxx} ;\n"
      end
    end

    # libdir should be set by --prefix but isn't
    icu4c_prefix = Formula["icu4c"].opt_prefix
    bootstrap_args = %W[
      --prefix=#{prefix}
      --libdir=#{lib}
      --with-icu=#{icu4c_prefix}
    ]

    # Handle libraries that will not be built.
    without_libraries = ["python", "mpi"]

    # Boost.Log cannot be built using Apple GCC at the moment. Disabled
    # on such systems.
    without_libraries << "log" if ENV.compiler == :gcc

    bootstrap_args << "--without-libraries=#{without_libraries.join(",")}"

    # layout should be synchronized with boost-python and boost-mpi
    args = %W[
      --prefix=#{prefix}
      --libdir=#{lib}
      -d2
      -j#{ENV.make_jobs}
      --layout=tagged-1.66
      --user-config=user-config.jam
      install
      threading=multi,single
      link=shared,static
    ]

    # Boost is using "clang++ -x c" to select C compiler which breaks C++14
    # handling using ENV.cxx14. Using "cxxflags" and "linkflags" still works.
    args << "cxxflags=-std=c++14"
    args << "cxxflags=-stdlib=libc++" << "linkflags=-stdlib=libc++" if ENV.compiler == :clang

    system "./bootstrap.sh", *bootstrap_args
    system "./b2", "headers"
    system "./b2", *args
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <boost/algorithm/string.hpp>
      #include <boost/iostreams/device/array.hpp>
      #include <boost/iostreams/device/back_inserter.hpp>
      #include <boost/iostreams/filter/zstd.hpp>
      #include <boost/iostreams/filtering_stream.hpp>
      #include <boost/iostreams/stream.hpp>

      #include <string>
      #include <iostream>
      #include <vector>
      #include <assert.h>

      using namespace boost::algorithm;
      using namespace boost::iostreams;
      using namespace std;

      int main()
      {
        string str("a,b");
        vector<string> strVec;
        split(strVec, str, is_any_of(","));
        assert(strVec.size()==2);
        assert(strVec[0]=="a");
        assert(strVec[1]=="b");

        // Test boost::iostreams::zstd_compressor() linking
        std::vector<char> v;
        back_insert_device<std::vector<char>> snk{v};
        filtering_ostream os;
        os.push(zstd_compressor());
        os.push(snk);
        os << "Boost" << std::flush;
        os.pop();

        array_source src{v.data(), v.size()};
        filtering_istream is;
        is.push(zstd_decompressor());
        is.push(src);
        std::string s;
        is >> s;

        assert(s == "Boost");

        return 0;
      }
    EOS
    system ENV.cxx, "test.cpp", "-std=c++14", "-o", "test", "-L#{lib}", "-lboost_iostreams",
                    "-L#{Formula["zstd"].opt_lib}", "-lzstd"
    system "./test"
  end
end

__END__
diff --git a/libs/process/include/boost/process/detail/posix/handles.hpp b/libs/process/include/boost/process/detail/posix/handles.hpp
index cd9e1ce5..304e77b1 100644
--- a/libs/process/include/boost/process/detail/posix/handles.hpp
+++ b/libs/process/include/boost/process/detail/posix/handles.hpp
@@ -33,7 +33,7 @@ inline std::vector<native_handle_type> get_handles(std::error_code & ec)
     else
         ec.clear();

-    auto my_fd = ::dirfd(dir.get());
+    auto my_fd = dirfd(dir.get());

     struct ::dirent * ent_p;

@@ -117,7 +117,7 @@ struct limit_handles_ : handler_base_ext
             return;
         }

-        auto my_fd = ::dirfd(dir);
+        auto my_fd = dirfd(dir);
         struct ::dirent * ent_p;

         while ((ent_p = readdir(dir)) != nullptr)

