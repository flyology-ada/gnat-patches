extern "C" void throw_cpp ()
{
  throw 42;
}

extern "C" int caught_cpp (int value) noexcept
{
  try
    {
      if (value < 0)
        throw 42;
      return value;
    }
  catch (...)
    {
      return -1;
    }
}
