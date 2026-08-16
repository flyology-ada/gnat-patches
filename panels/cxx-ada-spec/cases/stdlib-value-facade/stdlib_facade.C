#include <string>

extern "C" unsigned long string_length (const char *data, unsigned long size)
{
  return std::string (data, size).size ();
}
