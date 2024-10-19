-- A skeleton of an ADA program for an assignment in programming languages

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Integer_Text_IO;
with Ada.Numerics.Discrete_Random;


procedure Simulation is

   ----GLOBAL VARIABLES---

   numberOfProducers: constant Integer := 5;
   numberOfAssemblies: constant Integer := 3;
   numberOfConsumers: constant Integer := 2;

   subtype ProducerType is Integer range 1 .. numberOfProducers;   --podtypy okreslajace jakie
   subtype AssemblyType is Integer range 1 .. numberOfAssemblies;  --wartosci moge przyjmowac
   subtype ConsumerType is Integer range 1 .. numberOfConsumers;   --podane zmienne


   --each Producer is assigned a Product that it produces
   productName: constant array (ProducerType) of String(1 .. 9) := ("---Ser---", "-Szynka--", "-Salami--", "-Ananas--", "Pieczarki");
   --Assembly is a collection of products
   assemblyName: constant array (AssemblyType) of String(1 .. 11) := ("-Hawajska--", "-Pepperoni-", "Capricciosa");


   ----TASK DECLARATIONS----

   -- Producer produces determined product
   task type Producer is
      entry Start(product: in ProducerType; productionTime: in Integer);
   end Producer;

   -- Consumer gets an arbitrary assembly of several products from the buffer
   -- but he/she orders it randomly
   task type Consumer is
      entry Start(consumerNumber: in ConsumerType; consumptionTime: in Integer);
   end Consumer;

   -- Buffer receives products from Producers and delivers Assemblies to Consumers
   task type Buffer is
      -- Accept a product to the storage (provided there is a room for it)
      entry Take(product: in ProducerType; number: in Integer);
      -- Deliver an assembly (provided there are enough products for it)
      entry Deliver(assembly: in AssemblyType; number: out Integer);
      entry CleaningDay;
   end Buffer;

   task type Cleaning is
      entry Start(cleaningInterval: in Duration);
   end Cleaning;


   P: array ( 1 .. numberOfProducers ) of Producer;   --utworzenie instancji
   K: array ( 1 .. numberOfConsumers ) of Consumer;   --tak jakby obiektow (PO)
   B: Buffer;
   C: Cleaning;


   ----TASK DEFINITIONS----

   --Producer--

   task body Producer is
      subtype ProductionTimeRange is Integer range 1 .. 3;
      package RandomProduction is new Ada.Numerics.Discrete_Random(ProductionTimeRange);
      --  random number generator
      G: RandomProduction.Generator;
      producerTypeNumber: Integer;
      productNumber: Integer;
      production: Integer;
      randomTime: Duration;
   begin
      accept Start(product: in ProducerType; productionTime: in Integer) do
         --  start random number generator
         RandomProduction.Reset(G);
         productNumber := 1;   --ilosc (numer) wyprudukowanych produktow danego typu
         producerTypeNumber := product;   --stale przypisany do danego producenta (1-5)
         production := productionTime;   --ta zmienna nic nie robi
      end Start;
      Put_Line(ESC & "[93m" & "P: Started producer of " & productName(producerTypeNumber) & ESC & "[0m");
      loop
         randomTime := Duration(RandomProduction.Random(G));
         delay randomTime;
         Put_Line(ESC & "[93m" & "P: Produced product " & productName(producerTypeNumber) & " number "  & Integer'Image(productNumber) & ESC & "[0m");
         -- Accept for storage
         B.Take(producerTypeNumber, productNumber);   --przekazanie do bufora (bufor bierze)
         productNumber := productNumber + 1;
      end loop;
   end Producer;


   --Consumer--

   task body Consumer is
      subtype ConsumptionTimeRange is Integer range 4 .. 8;
      package RandomConsumption is new Ada.Numerics.Discrete_Random(ConsumptionTimeRange);
      --each Consumer takes any (random) Assembly from the Buffer
      package RandomAssembly is new Ada.Numerics.Discrete_Random(assemblyType);

      G: RandomConsumption.Generator;
      GA: RandomAssembly.Generator;
      consumerNb: ConsumerType;
      assemblyNumber: Integer;   --ilosc (numer) pobranego egzemplarza zestawu danego typu
      consumption: Integer;
      assemblyType: Integer;   --losowany typ zestawu (1-3)
      consumerName: constant array (1 .. numberOfConsumers) of String(1 .. 6) := ("Grubas", "Zarlok");
   begin
      accept Start(consumerNumber: in ConsumerType; consumptionTime: in Integer) do
         RandomConsumption.Reset(G);
         RandomAssembly.Reset(GA);
         consumerNb := consumerNumber;   --stale przypisany do danego consumenta (1-2)
         consumption := consumptionTime;   --ta zmienna nic nie robi
      end Start;
      Put_Line(ESC & "[96m" & "K: Started consumer " & consumerName(consumerNb) & ESC & "[0m");
      loop
         delay Duration(RandomConsumption.Random(G));   --simulate consumption
         assemblyType := RandomAssembly.Random(GA);
         -- take an assembly for consumption
         B.Deliver(assemblyType, assemblyNumber);
         Put_Line(ESC & "[96m" & "K: " & consumerName(consumerNb) & " takes assembly " & assemblyName(assemblyType) & " number " & Integer'Image(assemblyNumber) & ESC & "[0m");
      end loop;
   end Consumer;


   --Cleaning--

   task body Cleaning is
      dayNumber: Integer;
      interval : Duration;
   begin
      accept Start(cleaningInterval: in Duration) do
         dayNumber := 1;
         interval := cleaningInterval;
      end Start;
      Put_Line(ESC & "[92m" & "C: Cleaning task started." & ESC & "[0m");
      loop
         delay Duration(interval);  
         dayNumber := dayNumber + 1;
         Put_Line(ESC & "[92m" & "C: Day " & Integer'Image(dayNumber) & " passed." & ESC & "[0m");

         if dayNumber = 10 then
            Put_Line(ESC & "[92m" & "C: Cleaning day arrived!" & ESC & "[0m");
            B.CleaningDay;
            dayNumber := 1; 
         end if;
      end loop;
   end Cleaning;


   --Buffer--

   task body Buffer is
      storageCapacity: constant Integer := 30;
      type StorageType is array (producerType) of Integer;
      storage: StorageType := (0, 0, 0, 0, 0);   --przechowuje liczbe produktow od kadzego produceta
      reservedSpacesPerProduct: StorageType := (6, 4, 4, 4, 4); 
      
      assemblyContent: array(assemblyType, producerType) of Integer
        := ((2, 1, 0, 3, 0), --do utworzenia a.1 potrzeba produktow 2 od P(1), 1 od P(2) itd, 2 od P(3) itd.
            (2, 0, 3, 0, 0), -- ...
            (2, 2, 0, 0, 3)); -- ...
      maxAssemblyContent: array(producerType) of Integer;
      assemblyNumber: array(assemblyType) of Integer := (1, 1, 1);
      inStorage: Integer := 0;

      --wypelnia maxAssemblyContent (dla P1:3, P2:2, P3:2, P4:1, P5:2)
      procedure SetupVariables is
      begin
         for W in producerType loop
            maxAssemblyContent(W) := 0;
            for Z in assemblyType loop
               if assemblyContent(Z, W) > maxAssemblyContent(W) then
                  maxAssemblyContent(W) := assemblyContent(Z, W);
               end if;
            end loop;
         end loop;
      end SetupVariables;

      function CanAccept(product: ProducerType) return Boolean is   --tu nie trzeba przekazywac parametrow lol
         reservedSpaces : Integer := 0;
         
      begin
         for W in producerType loop
            if storage(W) < reservedSpacesPerProduct(W) then
               reservedSpaces := reservedSpaces +reservedSpacesPerProduct(W) - storage(W);
            end if;
         end loop;
         
         
         if inStorage + reservedSpaces >= storageCapacity then
            return False;
         else
            return True;
         end if;
      end CanAccept;

      --czy mozna zlozyc zamowienie na dany zestaw
      function CanDeliver(assembly: AssemblyType) return Boolean is
      begin
         for W in producerType loop
            if storage(W) < assemblyContent(assembly, W) then
               return False;
            end if;
         end loop;
         return True;
      end CanDeliver;
      
      procedure TodayIsCleaningDay is
      begin
         Put_Line(ESC & "[92m" & "C: Cleaning day: removing products." & ESC & "[0m");
         for W in ProducerType loop
            if storage(W) >= 3 then
               storage(W) := storage(W) - 3;
               inStorage := inStorage - 3;
               Put_Line(ESC & "[92m" & "C: Removed 3 " & productName(W) & " from storage." & ESC & "[0m");
            else
               Put_Line(ESC & "[92m" & "C: Not enough " & productName(W) & " to remove 3 items." & ESC & "[0m");
            end if;
         end loop;
      end TodayIsCleaningDay;

      procedure StorageContents is
      begin
         for W in producerType loop
            Put_Line("|   Storage contents: " & Integer'Image(storage(W)) & " " & productName(W));
         end loop;
         Put_Line("|   Number of products in storage: " & Integer'Image(inStorage));
      end StorageContents;

   begin
      Put_Line(ESC & "[91m" & "B: Buffer started" & ESC & "[0m");
      SetupVariables;
      loop
         select
            accept Take(product: in ProducerType; number: in Integer) do
               if CanAccept(product) then
                  Put_Line(ESC & "[91m" & "B: Accepted product " & productName(product) & " number " & Integer'Image(number)& ESC & "[0m");
                  storage(product) := storage(product) + 1;
                  inStorage := inStorage + 1;
               else
                  Put_Line(ESC & "[91m" & "B: Rejected product " & productName(product) & " number " & Integer'Image(number)& ESC & "[0m");
               end if;
            end Take;
            
         or   
            accept Deliver(assembly: in AssemblyType; number: out Integer) do
               if CanDeliver(assembly) then
                  Put_Line(ESC & "[91m" & "B: Delivered assembly " & assemblyName(assembly) & " number " & Integer'Image(assemblyNumber(assembly))& ESC & "[0m");
                  for W in producerType loop
                     storage(W) := storage(W) - assemblyContent(assembly, W);
                     inStorage := inStorage - assemblyContent(assembly, W);
                  end loop;
                  number := assemblyNumber(assembly);
                  assemblyNumber(assembly) := assemblyNumber(assembly) + 1;
               else
                  Put_Line(ESC & "[91m" & "B: Lacking products for assembly " & assemblyName(assembly)& ESC & "[0m");
                  number := 0;
               end if;
            end Deliver;
         
         or
            accept CleaningDay do
               TodayIsCleaningDay;
            end CleaningDay;
         end select;
         
            StorageContents;
      end loop;
   end Buffer;



   ---"MAIN" FOR SIMULATION---
begin
   for I in 1 .. numberOfProducers loop
      P(I).Start(I, 10);
   end loop;
   for J in 1 .. numberOfConsumers loop
      K(J).Start(J,12);
   end loop;
   C.Start(1.0);
end Simulation;



